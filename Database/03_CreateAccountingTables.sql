-- =============================================
-- Accounting & Financial Management Tables
-- Module: Chart of Accounts & Fiscal Periods
-- =============================================

USE VCIIAMS;
GO

-- =============================================
-- Account Types Lookup Table
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'AccountTypes')
BEGIN
    CREATE TABLE AccountTypes (
        AccountTypeId INT IDENTITY(1,1) PRIMARY KEY,
        TypeCode NVARCHAR(20) NOT NULL UNIQUE,
        TypeName NVARCHAR(50) NOT NULL,
        NormalBalance NVARCHAR(10) NOT NULL, -- DEBIT or CREDIT
        Category NVARCHAR(50) NOT NULL, -- ASSET, LIABILITY, EQUITY, REVENUE, EXPENSE
        DisplayOrder INT NOT NULL DEFAULT 0,
        IsActive BIT NOT NULL DEFAULT 1,
        CreatedBy NVARCHAR(100) NOT NULL,
        CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
        ModifiedBy NVARCHAR(100) NULL,
        ModifiedDate DATETIME NULL,
        CONSTRAINT CK_AccountTypes_NormalBalance CHECK (NormalBalance IN ('DEBIT', 'CREDIT')),
        CONSTRAINT CK_AccountTypes_Category CHECK (Category IN ('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE'))
    );

    CREATE INDEX IX_AccountTypes_Code ON AccountTypes(TypeCode);
    CREATE INDEX IX_AccountTypes_Category ON AccountTypes(Category);

    PRINT 'Table AccountTypes created successfully.';
END
GO

-- =============================================
-- Chart of Accounts Table
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'ChartOfAccounts')
BEGIN
    CREATE TABLE ChartOfAccounts (
        AccountId INT IDENTITY(1,1) PRIMARY KEY,
        AccountCode NVARCHAR(50) NOT NULL UNIQUE,
        AccountName NVARCHAR(200) NOT NULL,
        AccountTypeId INT NOT NULL,
        ParentAccountId INT NULL, -- For hierarchical account structure
        Description NVARCHAR(500) NULL,
        IsHeader BIT NOT NULL DEFAULT 0, -- Header accounts cannot have transactions
        IsActive BIT NOT NULL DEFAULT 1,
        AllowManualEntry BIT NOT NULL DEFAULT 1, -- Some accounts may be system-controlled
        Level INT NOT NULL DEFAULT 1, -- Account hierarchy level
        DepartmentId INT NULL, -- Optional department assignment

        -- Opening Balance
        OpeningBalance DECIMAL(18,2) NOT NULL DEFAULT 0,
        OpeningBalanceDate DATE NULL,

        -- Metadata
        CreatedBy NVARCHAR(100) NOT NULL,
        CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
        ModifiedBy NVARCHAR(100) NULL,
        ModifiedDate DATETIME NULL,

        CONSTRAINT FK_ChartOfAccounts_AccountType FOREIGN KEY (AccountTypeId)
            REFERENCES AccountTypes(AccountTypeId),
        CONSTRAINT FK_ChartOfAccounts_Parent FOREIGN KEY (ParentAccountId)
            REFERENCES ChartOfAccounts(AccountId),
        CONSTRAINT FK_ChartOfAccounts_Department FOREIGN KEY (DepartmentId)
            REFERENCES Departments(DepartmentId),
        CONSTRAINT CK_ChartOfAccounts_Level CHECK (Level > 0 AND Level <= 10)
    );

    CREATE INDEX IX_ChartOfAccounts_Code ON ChartOfAccounts(AccountCode);
    CREATE INDEX IX_ChartOfAccounts_Type ON ChartOfAccounts(AccountTypeId);
    CREATE INDEX IX_ChartOfAccounts_Parent ON ChartOfAccounts(ParentAccountId);
    CREATE INDEX IX_ChartOfAccounts_Active ON ChartOfAccounts(IsActive);
    CREATE INDEX IX_ChartOfAccounts_Header ON ChartOfAccounts(IsHeader);
    CREATE INDEX IX_ChartOfAccounts_Department ON ChartOfAccounts(DepartmentId);

    PRINT 'Table ChartOfAccounts created successfully.';
END
GO

-- =============================================
-- Fiscal Years Table
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'FiscalYears')
BEGIN
    CREATE TABLE FiscalYears (
        FiscalYearId INT IDENTITY(1,1) PRIMARY KEY,
        FiscalYearCode NVARCHAR(20) NOT NULL UNIQUE,
        FiscalYearName NVARCHAR(100) NOT NULL,
        StartDate DATE NOT NULL,
        EndDate DATE NOT NULL,
        IsClosed BIT NOT NULL DEFAULT 0,
        IsActive BIT NOT NULL DEFAULT 1,
        ClosedBy NVARCHAR(100) NULL,
        ClosedDate DATETIME NULL,
        CreatedBy NVARCHAR(100) NOT NULL,
        CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
        ModifiedBy NVARCHAR(100) NULL,
        ModifiedDate DATETIME NULL,
        CONSTRAINT CK_FiscalYears_Dates CHECK (EndDate > StartDate)
    );

    CREATE INDEX IX_FiscalYears_Code ON FiscalYears(FiscalYearCode);
    CREATE INDEX IX_FiscalYears_Dates ON FiscalYears(StartDate, EndDate);
    CREATE INDEX IX_FiscalYears_Active ON FiscalYears(IsActive);
    CREATE INDEX IX_FiscalYears_Closed ON FiscalYears(IsClosed);

    PRINT 'Table FiscalYears created successfully.';
END
GO

-- =============================================
-- Fiscal Periods Table (Monthly, Quarterly, etc.)
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'FiscalPeriods')
BEGIN
    CREATE TABLE FiscalPeriods (
        FiscalPeriodId INT IDENTITY(1,1) PRIMARY KEY,
        FiscalYearId INT NOT NULL,
        PeriodCode NVARCHAR(20) NOT NULL,
        PeriodName NVARCHAR(100) NOT NULL,
        PeriodType NVARCHAR(20) NOT NULL DEFAULT 'MONTHLY', -- MONTHLY, QUARTERLY, SEMI-ANNUAL
        StartDate DATE NOT NULL,
        EndDate DATE NOT NULL,
        PeriodNumber INT NOT NULL, -- 1-12 for monthly, 1-4 for quarterly
        IsClosed BIT NOT NULL DEFAULT 0,
        IsActive BIT NOT NULL DEFAULT 1,
        ClosedBy NVARCHAR(100) NULL,
        ClosedDate DATETIME NULL,
        CreatedBy NVARCHAR(100) NOT NULL,
        CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
        ModifiedBy NVARCHAR(100) NULL,
        ModifiedDate DATETIME NULL,

        CONSTRAINT FK_FiscalPeriods_FiscalYear FOREIGN KEY (FiscalYearId)
            REFERENCES FiscalYears(FiscalYearId) ON DELETE CASCADE,
        CONSTRAINT CK_FiscalPeriods_Dates CHECK (EndDate > StartDate),
        CONSTRAINT CK_FiscalPeriods_Type CHECK (PeriodType IN ('MONTHLY', 'QUARTERLY', 'SEMI-ANNUAL', 'ANNUAL')),
        CONSTRAINT UK_FiscalPeriods UNIQUE (FiscalYearId, PeriodCode)
    );

    CREATE INDEX IX_FiscalPeriods_Year ON FiscalPeriods(FiscalYearId);
    CREATE INDEX IX_FiscalPeriods_Dates ON FiscalPeriods(StartDate, EndDate);
    CREATE INDEX IX_FiscalPeriods_Number ON FiscalPeriods(PeriodNumber);
    CREATE INDEX IX_FiscalPeriods_Closed ON FiscalPeriods(IsClosed);
    CREATE INDEX IX_FiscalPeriods_Active ON FiscalPeriods(IsActive);

    PRINT 'Table FiscalPeriods created successfully.';
END
GO

-- =============================================
-- Account Balances Summary Table (for performance)
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'AccountBalances')
BEGIN
    CREATE TABLE AccountBalances (
        AccountBalanceId BIGINT IDENTITY(1,1) PRIMARY KEY,
        AccountId INT NOT NULL,
        FiscalPeriodId INT NOT NULL,
        OpeningBalance DECIMAL(18,2) NOT NULL DEFAULT 0,
        DebitAmount DECIMAL(18,2) NOT NULL DEFAULT 0,
        CreditAmount DECIMAL(18,2) NOT NULL DEFAULT 0,
        ClosingBalance DECIMAL(18,2) NOT NULL DEFAULT 0,
        LastUpdated DATETIME NOT NULL DEFAULT GETDATE(),

        CONSTRAINT FK_AccountBalances_Account FOREIGN KEY (AccountId)
            REFERENCES ChartOfAccounts(AccountId) ON DELETE CASCADE,
        CONSTRAINT FK_AccountBalances_Period FOREIGN KEY (FiscalPeriodId)
            REFERENCES FiscalPeriods(FiscalPeriodId) ON DELETE CASCADE,
        CONSTRAINT UK_AccountBalances UNIQUE (AccountId, FiscalPeriodId)
    );

    CREATE INDEX IX_AccountBalances_Account ON AccountBalances(AccountId);
    CREATE INDEX IX_AccountBalances_Period ON AccountBalances(FiscalPeriodId);
    CREATE INDEX IX_AccountBalances_Updated ON AccountBalances(LastUpdated);

    PRINT 'Table AccountBalances created successfully.';
END
GO

PRINT 'Accounting tables creation completed.';
GO
