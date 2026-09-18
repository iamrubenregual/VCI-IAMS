-- =============================================
-- Stored Procedures for Chart of Accounts & Fiscal Periods
-- =============================================

USE VCIIAMS;
GO

-- =============================================
-- SP: Get All Chart of Accounts
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'sp_GetAllChartOfAccounts')
    DROP PROCEDURE sp_GetAllChartOfAccounts;
GO

CREATE PROCEDURE sp_GetAllChartOfAccounts
    @IncludeInactive BIT = 0,
    @AccountTypeId INT = NULL,
    @DepartmentId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

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
        coa.Description,
        coa.IsHeader,
        coa.IsActive,
        coa.AllowManualEntry,
        coa.Level,
        coa.DepartmentId,
        d.DepartmentName,
        coa.OpeningBalance,
        coa.OpeningBalanceDate,
        coa.CreatedBy,
        coa.CreatedDate,
        coa.ModifiedBy,
        coa.ModifiedDate
    FROM ChartOfAccounts coa
    INNER JOIN AccountTypes at ON coa.AccountTypeId = at.AccountTypeId
    LEFT JOIN ChartOfAccounts parent ON coa.ParentAccountId = parent.AccountId
    LEFT JOIN Departments d ON coa.DepartmentId = d.DepartmentId
    WHERE
        (@IncludeInactive = 1 OR coa.IsActive = 1)
        AND (@AccountTypeId IS NULL OR coa.AccountTypeId = @AccountTypeId)
        AND (@DepartmentId IS NULL OR coa.DepartmentId = @DepartmentId)
    ORDER BY coa.AccountCode;
END
GO

-- =============================================
-- SP: Get Chart of Account by ID
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'sp_GetChartOfAccountById')
    DROP PROCEDURE sp_GetChartOfAccountById;
GO

CREATE PROCEDURE sp_GetChartOfAccountById
    @AccountId INT
AS
BEGIN
    SET NOCOUNT ON;

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
        coa.Description,
        coa.IsHeader,
        coa.IsActive,
        coa.AllowManualEntry,
        coa.Level,
        coa.DepartmentId,
        d.DepartmentName,
        coa.OpeningBalance,
        coa.OpeningBalanceDate,
        coa.CreatedBy,
        coa.CreatedDate,
        coa.ModifiedBy,
        coa.ModifiedDate
    FROM ChartOfAccounts coa
    INNER JOIN AccountTypes at ON coa.AccountTypeId = at.AccountTypeId
    LEFT JOIN ChartOfAccounts parent ON coa.ParentAccountId = parent.AccountId
    LEFT JOIN Departments d ON coa.DepartmentId = d.DepartmentId
    WHERE coa.AccountId = @AccountId;
END
GO

-- =============================================
-- SP: Create Chart of Account
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'sp_CreateChartOfAccount')
    DROP PROCEDURE sp_CreateChartOfAccount;
GO

CREATE PROCEDURE sp_CreateChartOfAccount
    @AccountCode NVARCHAR(50),
    @AccountName NVARCHAR(200),
    @AccountTypeId INT,
    @ParentAccountId INT = NULL,
    @Description NVARCHAR(500) = NULL,
    @IsHeader BIT = 0,
    @AllowManualEntry BIT = 1,
    @Level INT = 1,
    @DepartmentId INT = NULL,
    @OpeningBalance DECIMAL(18,2) = 0,
    @OpeningBalanceDate DATE = NULL,
    @CreatedBy NVARCHAR(100),
    @NewAccountId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Check if account code already exists
        IF EXISTS (SELECT 1 FROM ChartOfAccounts WHERE AccountCode = @AccountCode)
        BEGIN
            RAISERROR('Account code already exists.', 16, 1);
            RETURN -1;
        END

        -- Validate parent account if specified
        IF @ParentAccountId IS NOT NULL
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM ChartOfAccounts WHERE AccountId = @ParentAccountId AND IsActive = 1 AND IsHeader = 1)
            BEGIN
                RAISERROR('Parent account does not exist, is inactive, or is not a header account.', 16, 1);
                RETURN -2;
            END

            IF EXISTS (
                SELECT 1 FROM ChartOfAccounts child
                INNER JOIN AccountTypes childType ON childType.AccountTypeId = @AccountTypeId
                INNER JOIN ChartOfAccounts parent ON parent.AccountId = @ParentAccountId
                INNER JOIN AccountTypes parentType ON parentType.AccountTypeId = parent.AccountTypeId
                WHERE child.AccountId = @ParentAccountId AND childType.Category <> parentType.Category
            )
            BEGIN
                RAISERROR('Parent and child accounts must have compatible account types.', 16, 1);
                RETURN -3;
            END
        END

        IF NOT EXISTS (SELECT 1 FROM AccountTypes WHERE AccountTypeId = @AccountTypeId AND IsActive = 1)
        BEGIN
            RAISERROR('Account type does not exist or is inactive.', 16, 1);
            RETURN -4;
        END

        IF @IsHeader = 1 AND (@AllowManualEntry = 1 OR @OpeningBalance <> 0)
        BEGIN
            RAISERROR('Header accounts cannot allow manual entry or have an opening balance.', 16, 1);
            RETURN -5;
        END

        IF @ParentAccountId IS NOT NULL
            SELECT @Level = Level + 1 FROM ChartOfAccounts WHERE AccountId = @ParentAccountId;
        ELSE
            SET @Level = 1;

        -- Insert new account
        INSERT INTO ChartOfAccounts (
            AccountCode, AccountName, AccountTypeId, ParentAccountId,
            Description, IsHeader, IsActive, AllowManualEntry, Level,
            DepartmentId, OpeningBalance, OpeningBalanceDate, CreatedBy, CreatedDate
        )
        VALUES (
            @AccountCode, @AccountName, @AccountTypeId, @ParentAccountId,
            @Description, @IsHeader, 1, @AllowManualEntry, @Level,
            @DepartmentId, @OpeningBalance, @OpeningBalanceDate, @CreatedBy, GETDATE()
        );

        SET @NewAccountId = SCOPE_IDENTITY();

        -- Log the action
        INSERT INTO AuditLogs (Username, Action, TableName, RecordId, NewValues, ActionDate)
        VALUES (@CreatedBy, 'INSERT', 'ChartOfAccounts', CAST(@NewAccountId AS NVARCHAR),
                'AccountCode: ' + @AccountCode + ', AccountName: ' + @AccountName, GETDATE());

        COMMIT TRANSACTION;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();

        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
        RETURN -999;
    END CATCH
END
GO

-- =============================================
-- SP: Update Chart of Account
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'sp_UpdateChartOfAccount')
    DROP PROCEDURE sp_UpdateChartOfAccount;
GO

CREATE PROCEDURE sp_UpdateChartOfAccount
    @AccountId INT,
    @AccountCode NVARCHAR(50),
    @AccountName NVARCHAR(200),
    @AccountTypeId INT,
    @ParentAccountId INT = NULL,
    @Description NVARCHAR(500) = NULL,
    @IsHeader BIT = 0,
    @AllowManualEntry BIT = 1,
    @Level INT = 1,
    @DepartmentId INT = NULL,
    @OpeningBalance DECIMAL(18,2) = 0,
    @OpeningBalanceDate DATE = NULL,
    @ModifiedBy NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Check if account exists
        IF NOT EXISTS (SELECT 1 FROM ChartOfAccounts WHERE AccountId = @AccountId)
        BEGIN
            RAISERROR('Account does not exist.', 16, 1);
            RETURN -1;
        END

        -- Check if account code is being changed to an existing code
        IF EXISTS (SELECT 1 FROM ChartOfAccounts WHERE AccountCode = @AccountCode AND AccountId <> @AccountId)
        BEGIN
            RAISERROR('Account code already exists for another account.', 16, 1);
            RETURN -2;
        END

        -- Prevent circular reference in parent hierarchy
        IF @ParentAccountId IS NOT NULL AND @ParentAccountId = @AccountId
        BEGIN
            RAISERROR('An account cannot be its own parent.', 16, 1);
            RETURN -3;
        END

        IF @ParentAccountId IS NOT NULL
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM ChartOfAccounts WHERE AccountId = @ParentAccountId AND IsActive = 1 AND IsHeader = 1)
            BEGIN
                RAISERROR('Parent account does not exist, is inactive, or is not a header account.', 16, 1);
                RETURN -4;
            END

            DECLARE @CreatesCycle BIT = 0;
            ;WITH Ancestors AS
            (
                SELECT AccountId, ParentAccountId
                FROM ChartOfAccounts
                WHERE AccountId = @ParentAccountId
                UNION ALL
                SELECT parent.AccountId, parent.ParentAccountId
                FROM ChartOfAccounts parent
                INNER JOIN Ancestors ancestor ON ancestor.ParentAccountId = parent.AccountId
            )
            SELECT @CreatesCycle = 1 FROM Ancestors WHERE AccountId = @AccountId;

            IF @CreatesCycle = 1
            BEGIN
                RAISERROR('The selected parent would create a circular hierarchy.', 16, 1);
                RETURN -5;
            END

            IF EXISTS (
                SELECT 1
                FROM ChartOfAccounts parent
                INNER JOIN AccountTypes parentType ON parentType.AccountTypeId = parent.AccountTypeId
                INNER JOIN AccountTypes childType ON childType.AccountTypeId = @AccountTypeId
                WHERE parent.AccountId = @ParentAccountId
                  AND parentType.Category <> childType.Category
            )
            BEGIN
                RAISERROR('Parent and child accounts must have compatible account types.', 16, 1);
                RETURN -9;
            END
        END

        IF NOT EXISTS (SELECT 1 FROM AccountTypes WHERE AccountTypeId = @AccountTypeId AND IsActive = 1)
        BEGIN
            RAISERROR('Account type does not exist or is inactive.', 16, 1);
            RETURN -6;
        END

        IF @IsHeader = 1 AND (@AllowManualEntry = 1 OR @OpeningBalance <> 0)
        BEGIN
            RAISERROR('Header accounts cannot allow manual entry or have an opening balance.', 16, 1);
            RETURN -7;
        END

        IF @IsHeader = 0 AND EXISTS (SELECT 1 FROM ChartOfAccounts WHERE ParentAccountId = @AccountId AND IsActive = 1)
        BEGIN
            RAISERROR('An account with active child accounts must remain a header account.', 16, 1);
            RETURN -8;
        END

        IF EXISTS (SELECT 1 FROM AccountBalances WHERE AccountId = @AccountId AND (DebitAmount <> 0 OR CreditAmount <> 0))
           AND EXISTS (SELECT 1 FROM ChartOfAccounts WHERE AccountId = @AccountId AND AccountCode <> @AccountCode)
        BEGIN
            RAISERROR('Account code cannot be changed after the account has activity.', 16, 1);
            RETURN -8;
        END

        IF @ParentAccountId IS NOT NULL
            SELECT @Level = Level + 1 FROM ChartOfAccounts WHERE AccountId = @ParentAccountId;
        ELSE
            SET @Level = 1;

        -- Store old values for audit
        DECLARE @OldValues NVARCHAR(MAX);
        SELECT @OldValues = 'AccountCode: ' + AccountCode + ', AccountName: ' + AccountName
        FROM ChartOfAccounts WHERE AccountId = @AccountId;

        -- Update the account
        UPDATE ChartOfAccounts
        SET
            AccountCode = @AccountCode,
            AccountName = @AccountName,
            AccountTypeId = @AccountTypeId,
            ParentAccountId = @ParentAccountId,
            Description = @Description,
            IsHeader = @IsHeader,
            AllowManualEntry = @AllowManualEntry,
            Level = @Level,
            DepartmentId = @DepartmentId,
            OpeningBalance = @OpeningBalance,
            OpeningBalanceDate = @OpeningBalanceDate,
            ModifiedBy = @ModifiedBy,
            ModifiedDate = GETDATE()
        WHERE AccountId = @AccountId;

        -- Log the action
        INSERT INTO AuditLogs (Username, Action, TableName, RecordId, OldValues, NewValues, ActionDate)
        VALUES (@ModifiedBy, 'UPDATE', 'ChartOfAccounts', CAST(@AccountId AS NVARCHAR),
                @OldValues, 'AccountCode: ' + @AccountCode + ', AccountName: ' + @AccountName, GETDATE());

        COMMIT TRANSACTION;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();

        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
        RETURN -999;
    END CATCH
END
GO

-- =============================================
-- SP: Delete (Soft Delete) Chart of Account
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'sp_DeleteChartOfAccount')
    DROP PROCEDURE sp_DeleteChartOfAccount;
GO

CREATE PROCEDURE sp_DeleteChartOfAccount
    @AccountId INT,
    @DeletedBy NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Check if account exists
        IF NOT EXISTS (SELECT 1 FROM ChartOfAccounts WHERE AccountId = @AccountId)
        BEGIN
            RAISERROR('Account does not exist.', 16, 1);
            RETURN -1;
        END

        -- Check if account has child accounts
        IF EXISTS (SELECT 1 FROM ChartOfAccounts WHERE ParentAccountId = @AccountId AND IsActive = 1)
        BEGIN
            RAISERROR('Cannot delete account with active child accounts.', 16, 1);
            RETURN -2;
        END

        IF EXISTS (SELECT 1 FROM AccountBalances WHERE AccountId = @AccountId AND (DebitAmount <> 0 OR CreditAmount <> 0))
        BEGIN
            RAISERROR('This account cannot be deleted because it has accounting activity.', 16, 1);
            RETURN -3;
        END

        -- Soft delete the account
        UPDATE ChartOfAccounts
        SET
            IsActive = 0,
            ModifiedBy = @DeletedBy,
            ModifiedDate = GETDATE()
        WHERE AccountId = @AccountId;

        -- Log the action
        INSERT INTO AuditLogs (Username, Action, TableName, RecordId, ActionDate)
        VALUES (@DeletedBy, 'DELETE', 'ChartOfAccounts', CAST(@AccountId AS NVARCHAR), GETDATE());

        COMMIT TRANSACTION;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();

        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
        RETURN -999;
    END CATCH
END
GO

-- =============================================
-- FISCAL PERIODS STORED PROCEDURES
-- =============================================

-- =============================================
-- SP: Get All Fiscal Years
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'sp_GetAllFiscalYears')
    DROP PROCEDURE sp_GetAllFiscalYears;
GO

CREATE PROCEDURE sp_GetAllFiscalYears
    @IncludeInactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        FiscalYearId,
        FiscalYearCode,
        FiscalYearName,
        StartDate,
        EndDate,
        IsClosed,
        IsActive,
        ClosedBy,
        ClosedDate,
        CreatedBy,
        CreatedDate,
        ModifiedBy,
        ModifiedDate,
        (SELECT COUNT(*) FROM FiscalPeriods WHERE FiscalYearId = fy.FiscalYearId) AS PeriodCount
    FROM FiscalYears fy
    WHERE @IncludeInactive = 1 OR IsActive = 1
    ORDER BY StartDate DESC;
END
GO

-- =============================================
-- SP: Get Fiscal Year by ID
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'sp_GetFiscalYearById')
    DROP PROCEDURE sp_GetFiscalYearById;
GO

CREATE PROCEDURE sp_GetFiscalYearById
    @FiscalYearId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        FiscalYearId,
        FiscalYearCode,
        FiscalYearName,
        StartDate,
        EndDate,
        IsClosed,
        IsActive,
        ClosedBy,
        ClosedDate,
        CreatedBy,
        CreatedDate,
        ModifiedBy,
        ModifiedDate
    FROM FiscalYears
    WHERE FiscalYearId = @FiscalYearId;
END
GO

-- =============================================
-- SP: Create Fiscal Year
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'sp_CreateFiscalYear')
    DROP PROCEDURE sp_CreateFiscalYear;
GO

CREATE PROCEDURE sp_CreateFiscalYear
    @FiscalYearCode NVARCHAR(20),
    @FiscalYearName NVARCHAR(100),
    @StartDate DATE,
    @EndDate DATE,
    @CreatePeriods BIT = 1, -- Automatically create monthly periods
    @CreatedBy NVARCHAR(100),
    @NewFiscalYearId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validation
        IF @EndDate <= @StartDate
        BEGIN
            RAISERROR('End date must be after start date.', 16, 1);
            RETURN -1;
        END

        -- Check for duplicate fiscal year code
        IF EXISTS (SELECT 1 FROM FiscalYears WHERE FiscalYearCode = @FiscalYearCode)
        BEGIN
            RAISERROR('Fiscal year code already exists.', 16, 1);
            RETURN -2;
        END

        -- Check for overlapping fiscal years
        IF EXISTS (
            SELECT 1 FROM FiscalYears
            WHERE IsActive = 1
            AND (
                (@StartDate BETWEEN StartDate AND EndDate) OR
                (@EndDate BETWEEN StartDate AND EndDate) OR
                (StartDate BETWEEN @StartDate AND @EndDate)
            )
        )
        BEGIN
            RAISERROR('Fiscal year dates overlap with existing fiscal year.', 16, 1);
            RETURN -3;
        END

        -- Insert fiscal year
        INSERT INTO FiscalYears (FiscalYearCode, FiscalYearName, StartDate, EndDate, CreatedBy, CreatedDate)
        VALUES (@FiscalYearCode, @FiscalYearName, @StartDate, @EndDate, @CreatedBy, GETDATE());

        SET @NewFiscalYearId = SCOPE_IDENTITY();

        -- Automatically create monthly periods if requested
        IF @CreatePeriods = 1
        BEGIN
            DECLARE @CurrentDate DATE = @StartDate;
            DECLARE @PeriodEndDate DATE;
            DECLARE @PeriodNum INT = 1;

            WHILE @CurrentDate <= @EndDate
            BEGIN
                -- Calculate period end date (last day of month or fiscal year end)
                SET @PeriodEndDate = EOMONTH(@CurrentDate);
                IF @PeriodEndDate > @EndDate
                    SET @PeriodEndDate = @EndDate;

                -- Insert period
                INSERT INTO FiscalPeriods (
                    FiscalYearId, PeriodCode, PeriodName, PeriodType,
                    StartDate, EndDate, PeriodNumber, CreatedBy, CreatedDate
                )
                VALUES (
                    @NewFiscalYearId,
                    @FiscalYearCode + '-' + RIGHT('0' + CAST(@PeriodNum AS VARCHAR(2)), 2),
                    DATENAME(MONTH, @CurrentDate) + ' ' + CAST(YEAR(@CurrentDate) AS VARCHAR(4)),
                    'MONTHLY',
                    @CurrentDate,
                    @PeriodEndDate,
                    @PeriodNum,
                    @CreatedBy,
                    GETDATE()
                );

                -- Move to next month
                SET @CurrentDate = DATEADD(DAY, 1, @PeriodEndDate);
                SET @PeriodNum = @PeriodNum + 1;
            END
        END

        -- Log the action
        INSERT INTO AuditLogs (Username, Action, TableName, RecordId, NewValues, ActionDate)
        VALUES (@CreatedBy, 'INSERT', 'FiscalYears', CAST(@NewFiscalYearId AS NVARCHAR),
                'FiscalYearCode: ' + @FiscalYearCode, GETDATE());

        COMMIT TRANSACTION;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();

        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
        RETURN -999;
    END CATCH
END
GO

-- =============================================
-- SP: Update Fiscal Year
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'sp_UpdateFiscalYear')
    DROP PROCEDURE sp_UpdateFiscalYear;
GO

CREATE PROCEDURE sp_UpdateFiscalYear
    @FiscalYearId INT,
    @FiscalYearCode NVARCHAR(20),
    @FiscalYearName NVARCHAR(100),
    @StartDate DATE,
    @EndDate DATE,
    @ModifiedBy NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Check if fiscal year exists
        IF NOT EXISTS (SELECT 1 FROM FiscalYears WHERE FiscalYearId = @FiscalYearId)
        BEGIN
            RAISERROR('Fiscal year does not exist.', 16, 1);
            RETURN -1;
        END

        -- Check if fiscal year is closed
        IF EXISTS (SELECT 1 FROM FiscalYears WHERE FiscalYearId = @FiscalYearId AND IsClosed = 1)
        BEGIN
            RAISERROR('Cannot modify a closed fiscal year.', 16, 1);
            RETURN -2;
        END

        -- Validation
        IF @EndDate <= @StartDate
        BEGIN
            RAISERROR('End date must be after start date.', 16, 1);
            RETURN -3;
        END

        -- Update fiscal year
        UPDATE FiscalYears
        SET
            FiscalYearCode = @FiscalYearCode,
            FiscalYearName = @FiscalYearName,
            StartDate = @StartDate,
            EndDate = @EndDate,
            ModifiedBy = @ModifiedBy,
            ModifiedDate = GETDATE()
        WHERE FiscalYearId = @FiscalYearId;

        -- Log the action
        INSERT INTO AuditLogs (Username, Action, TableName, RecordId, NewValues, ActionDate)
        VALUES (@ModifiedBy, 'UPDATE', 'FiscalYears', CAST(@FiscalYearId AS NVARCHAR),
                'FiscalYearCode: ' + @FiscalYearCode, GETDATE());

        COMMIT TRANSACTION;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();

        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
        RETURN -999;
    END CATCH
END
GO

-- =============================================
-- SP: Get All Fiscal Periods
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'sp_GetAllFiscalPeriods')
    DROP PROCEDURE sp_GetAllFiscalPeriods;
GO

CREATE PROCEDURE sp_GetAllFiscalPeriods
    @FiscalYearId INT = NULL,
    @IncludeInactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        fp.FiscalPeriodId,
        fp.FiscalYearId,
        fy.FiscalYearCode,
        fy.FiscalYearName,
        fp.PeriodCode,
        fp.PeriodName,
        fp.PeriodType,
        fp.StartDate,
        fp.EndDate,
        fp.PeriodNumber,
        fp.IsClosed,
        fp.IsActive,
        fp.ClosedBy,
        fp.ClosedDate,
        fp.CreatedBy,
        fp.CreatedDate,
        fp.ModifiedBy,
        fp.ModifiedDate
    FROM FiscalPeriods fp
    INNER JOIN FiscalYears fy ON fp.FiscalYearId = fy.FiscalYearId
    WHERE
        (@FiscalYearId IS NULL OR fp.FiscalYearId = @FiscalYearId)
        AND (@IncludeInactive = 1 OR fp.IsActive = 1)
    ORDER BY fp.StartDate;
END
GO

-- =============================================
-- SP: Close Fiscal Period
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'sp_CloseFiscalPeriod')
    DROP PROCEDURE sp_CloseFiscalPeriod;
GO

CREATE PROCEDURE sp_CloseFiscalPeriod
    @FiscalPeriodId INT,
    @ClosedBy NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Check if period exists
        IF NOT EXISTS (SELECT 1 FROM FiscalPeriods WHERE FiscalPeriodId = @FiscalPeriodId)
        BEGIN
            RAISERROR('Fiscal period does not exist.', 16, 1);
            RETURN -1;
        END

        -- Check if already closed
        IF EXISTS (SELECT 1 FROM FiscalPeriods WHERE FiscalPeriodId = @FiscalPeriodId AND IsClosed = 1)
        BEGIN
            RAISERROR('Fiscal period is already closed.', 16, 1);
            RETURN -2;
        END

        -- Close the period
        UPDATE FiscalPeriods
        SET
            IsClosed = 1,
            ClosedBy = @ClosedBy,
            ClosedDate = GETDATE(),
            ModifiedBy = @ClosedBy,
            ModifiedDate = GETDATE()
        WHERE FiscalPeriodId = @FiscalPeriodId;

        -- Log the action
        INSERT INTO AuditLogs (Username, Action, TableName, RecordId, NewValues, ActionDate)
        VALUES (@ClosedBy, 'CLOSE', 'FiscalPeriods', CAST(@FiscalPeriodId AS NVARCHAR),
                'Period Closed', GETDATE());

        COMMIT TRANSACTION;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();

        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
        RETURN -999;
    END CATCH
END
GO

PRINT 'Stored procedures created successfully.';
GO
