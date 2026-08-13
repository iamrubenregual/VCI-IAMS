-- =============================================
-- Functions and Views for Chart of Accounts & Fiscal Periods
-- =============================================

USE VCIIAMS;
GO

-- =============================================
-- Function: Get Account Hierarchy Path
-- Returns the full hierarchy path of an account
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'FN' AND name = 'fn_GetAccountHierarchyPath')
    DROP FUNCTION fn_GetAccountHierarchyPath;
GO

CREATE FUNCTION fn_GetAccountHierarchyPath(@AccountId INT)
RETURNS NVARCHAR(1000)
AS
BEGIN
    DECLARE @Path NVARCHAR(1000) = '';
    DECLARE @CurrentAccountId INT = @AccountId;
    DECLARE @CurrentCode NVARCHAR(50);
    DECLARE @ParentId INT;
    DECLARE @Level INT = 0;
    DECLARE @MaxLevel INT = 10; -- Prevent infinite loop

    WHILE @CurrentAccountId IS NOT NULL AND @Level < @MaxLevel
    BEGIN
        SELECT
            @CurrentCode = AccountCode,
            @ParentId = ParentAccountId
        FROM ChartOfAccounts
        WHERE AccountId = @CurrentAccountId;

        IF @Path = ''
            SET @Path = @CurrentCode;
        ELSE
            SET @Path = @CurrentCode + ' > ' + @Path;

        SET @CurrentAccountId = @ParentId;
        SET @Level = @Level + 1;
    END

    RETURN @Path;
END
GO

-- =============================================
-- Function: Get Current Fiscal Period
-- Returns the current active fiscal period based on current date
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'FN' AND name = 'fn_GetCurrentFiscalPeriod')
    DROP FUNCTION fn_GetCurrentFiscalPeriod;
GO

CREATE FUNCTION fn_GetCurrentFiscalPeriod()
RETURNS INT
AS
BEGIN
    DECLARE @CurrentPeriodId INT;

    SELECT TOP 1 @CurrentPeriodId = FiscalPeriodId
    FROM FiscalPeriods
    WHERE
        GETDATE() BETWEEN StartDate AND EndDate
        AND IsActive = 1
        AND IsClosed = 0
    ORDER BY StartDate DESC;

    RETURN @CurrentPeriodId;
END
GO

-- =============================================
-- Function: Check if Account has Transactions
-- Returns 1 if account has transactions, 0 otherwise
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'FN' AND name = 'fn_AccountHasTransactions')
    DROP FUNCTION fn_AccountHasTransactions;
GO

CREATE FUNCTION fn_AccountHasTransactions(@AccountId INT)
RETURNS BIT
AS
BEGIN
    DECLARE @HasTransactions BIT = 0;

    -- Check if account has any balance records
    IF EXISTS (
        SELECT 1 FROM AccountBalances
        WHERE AccountId = @AccountId
        AND (DebitAmount <> 0 OR CreditAmount <> 0)
    )
    BEGIN
        SET @HasTransactions = 1;
    END

    RETURN @HasTransactions;
END
GO

-- =============================================
-- Function: Get Fiscal Year Status
-- Returns status of fiscal year (OPEN, CLOSED, UPCOMING, PAST)
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'FN' AND name = 'fn_GetFiscalYearStatus')
    DROP FUNCTION fn_GetFiscalYearStatus;
GO

CREATE FUNCTION fn_GetFiscalYearStatus(@FiscalYearId INT)
RETURNS NVARCHAR(20)
AS
BEGIN
    DECLARE @Status NVARCHAR(20);
    DECLARE @IsClosed BIT;
    DECLARE @StartDate DATE;
    DECLARE @EndDate DATE;
    DECLARE @CurrentDate DATE = CAST(GETDATE() AS DATE);

    SELECT
        @IsClosed = IsClosed,
        @StartDate = StartDate,
        @EndDate = EndDate
    FROM FiscalYears
    WHERE FiscalYearId = @FiscalYearId;

    IF @IsClosed = 1
        SET @Status = 'CLOSED';
    ELSE IF @CurrentDate < @StartDate
        SET @Status = 'UPCOMING';
    ELSE IF @CurrentDate > @EndDate
        SET @Status = 'PAST';
    ELSE
        SET @Status = 'OPEN';

    RETURN @Status;
END
GO

-- =============================================
-- VIEW: Chart of Accounts with Account Type Details
-- =============================================
IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_ChartOfAccountsWithDetails')
    DROP VIEW vw_ChartOfAccountsWithDetails;
GO

CREATE VIEW vw_ChartOfAccountsWithDetails
AS
SELECT
    coa.AccountId,
    coa.AccountCode,
    coa.AccountName,
    coa.AccountTypeId,
    at.TypeCode,
    at.TypeName,
    at.NormalBalance,
    at.Category,
    coa.ParentAccountId,
    parent.AccountCode AS ParentAccountCode,
    parent.AccountName AS ParentAccountName,
    dbo.fn_GetAccountHierarchyPath(coa.AccountId) AS HierarchyPath,
    coa.Description,
    coa.IsHeader,
    coa.IsActive,
    coa.AllowManualEntry,
    coa.Level,
    coa.DepartmentId,
    d.DepartmentCode,
    d.DepartmentName,
    coa.OpeningBalance,
    coa.OpeningBalanceDate,
    dbo.fn_AccountHasTransactions(coa.AccountId) AS HasTransactions,
    coa.CreatedBy,
    coa.CreatedDate,
    coa.ModifiedBy,
    coa.ModifiedDate
FROM ChartOfAccounts coa
INNER JOIN AccountTypes at ON coa.AccountTypeId = at.AccountTypeId
LEFT JOIN ChartOfAccounts parent ON coa.ParentAccountId = parent.AccountId
LEFT JOIN Departments d ON coa.DepartmentId = d.DepartmentId;
GO

-- =============================================
-- VIEW: Fiscal Periods with Year Details
-- =============================================
IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_FiscalPeriodsWithYearDetails')
    DROP VIEW vw_FiscalPeriodsWithYearDetails;
GO

CREATE VIEW vw_FiscalPeriodsWithYearDetails
AS
SELECT
    fp.FiscalPeriodId,
    fp.FiscalYearId,
    fy.FiscalYearCode,
    fy.FiscalYearName,
    fy.IsClosed AS YearIsClosed,
    dbo.fn_GetFiscalYearStatus(fy.FiscalYearId) AS YearStatus,
    fp.PeriodCode,
    fp.PeriodName,
    fp.PeriodType,
    fp.StartDate,
    fp.EndDate,
    fp.PeriodNumber,
    fp.IsClosed AS PeriodIsClosed,
    fp.IsActive,
    CASE
        WHEN fp.IsClosed = 1 THEN 'CLOSED'
        WHEN CAST(GETDATE() AS DATE) < fp.StartDate THEN 'UPCOMING'
        WHEN CAST(GETDATE() AS DATE) > fp.EndDate THEN 'PAST'
        ELSE 'CURRENT'
    END AS PeriodStatus,
    DATEDIFF(DAY, fp.StartDate, fp.EndDate) + 1 AS DaysInPeriod,
    fp.ClosedBy,
    fp.ClosedDate,
    fp.CreatedBy,
    fp.CreatedDate,
    fp.ModifiedBy,
    fp.ModifiedDate
FROM FiscalPeriods fp
INNER JOIN FiscalYears fy ON fp.FiscalYearId = fy.FiscalYearId;
GO

-- =============================================
-- VIEW: Account Balances Summary
-- =============================================
IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_AccountBalancesSummary')
    DROP VIEW vw_AccountBalancesSummary;
GO

CREATE VIEW vw_AccountBalancesSummary
AS
SELECT
    ab.AccountBalanceId,
    ab.AccountId,
    coa.AccountCode,
    coa.AccountName,
    at.TypeCode,
    at.TypeName,
    at.Category,
    at.NormalBalance,
    ab.FiscalPeriodId,
    fp.PeriodCode,
    fp.PeriodName,
    fy.FiscalYearCode,
    fy.FiscalYearName,
    ab.OpeningBalance,
    ab.DebitAmount,
    ab.CreditAmount,
    ab.ClosingBalance,
    CASE
        WHEN at.NormalBalance = 'DEBIT' THEN ab.ClosingBalance
        ELSE -ab.ClosingBalance
    END AS NormalBalanceAmount,
    ab.LastUpdated
FROM AccountBalances ab
INNER JOIN ChartOfAccounts coa ON ab.AccountId = coa.AccountId
INNER JOIN AccountTypes at ON coa.AccountTypeId = at.AccountTypeId
INNER JOIN FiscalPeriods fp ON ab.FiscalPeriodId = fp.FiscalPeriodId
INNER JOIN FiscalYears fy ON fp.FiscalYearId = fy.FiscalYearId;
GO

-- =============================================
-- VIEW: Active Accounts Hierarchy
-- Shows only active accounts in a tree structure
-- =============================================
IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_ActiveAccountsHierarchy')
    DROP VIEW vw_ActiveAccountsHierarchy;
GO

CREATE VIEW vw_ActiveAccountsHierarchy
AS
WITH AccountHierarchy AS (
    -- Root level accounts
    SELECT
        AccountId,
        AccountCode,
        AccountName,
        AccountTypeId,
        ParentAccountId,
        IsHeader,
        Level,
        CAST(AccountCode AS NVARCHAR(1000)) AS SortPath,
        0 AS HierarchyLevel
    FROM ChartOfAccounts
    WHERE ParentAccountId IS NULL AND IsActive = 1

    UNION ALL

    -- Child accounts
    SELECT
        coa.AccountId,
        coa.AccountCode,
        coa.AccountName,
        coa.AccountTypeId,
        coa.ParentAccountId,
        coa.IsHeader,
        coa.Level,
        CAST(ah.SortPath + ' > ' + coa.AccountCode AS NVARCHAR(1000)),
        ah.HierarchyLevel + 1
    FROM ChartOfAccounts coa
    INNER JOIN AccountHierarchy ah ON coa.ParentAccountId = ah.AccountId
    WHERE coa.IsActive = 1
)
SELECT
    ah.*,
    at.TypeCode,
    at.TypeName,
    at.Category,
    at.NormalBalance
FROM AccountHierarchy ah
INNER JOIN AccountTypes at ON ah.AccountTypeId = at.AccountTypeId;
GO

PRINT 'Functions and views created successfully.';
GO
