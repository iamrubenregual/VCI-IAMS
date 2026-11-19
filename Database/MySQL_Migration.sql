-- ============================================================================
-- VCI-IAMS Database Migration: MSSQL to MySQL 8.0+
-- Valencia Colleges (Bukidnon), Inc.
-- Phase 1 & Phase 2 General Ledger Migration Script
-- ============================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------------------------------------------------------
-- Database Initialization
-- ----------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS `vciiams`
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE `vciiams`;

SET GLOBAL log_bin_trust_function_creators = 1;

-- ============================================================================
-- 1. TABLES & CONSTRAINTS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: Departments
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS `Departments`;
CREATE TABLE `Departments` (
    `DepartmentId` INT AUTO_INCREMENT NOT NULL,
    `DepartmentCode` VARCHAR(20) NOT NULL,
    `DepartmentName` VARCHAR(100) NOT NULL,
    `Description` VARCHAR(500) NULL,
    `ParentDepartmentId` INT NULL,
    `IsActive` BOOLEAN NOT NULL DEFAULT 1,
    `CreatedBy` VARCHAR(100) NOT NULL,
    `CreatedDate` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `ModifiedBy` VARCHAR(100) NULL,
    `ModifiedDate` DATETIME NULL,
    PRIMARY KEY (`DepartmentId`),
    UNIQUE KEY `UK_Departments_Code` (`DepartmentCode`),
    INDEX `IX_Departments_Active` (`IsActive`),
    CONSTRAINT `FK_Departments_Parent` FOREIGN KEY (`ParentDepartmentId`)
        REFERENCES `Departments` (`DepartmentId`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- Table: Users
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS `Users`;
CREATE TABLE `Users` (
    `UserId` INT AUTO_INCREMENT NOT NULL,
    `Username` VARCHAR(50) NOT NULL,
    `Email` VARCHAR(100) NOT NULL,
    `PasswordHash` VARCHAR(255) NOT NULL,
    `PasswordSalt` VARCHAR(255) NOT NULL,
    `FirstName` VARCHAR(50) NOT NULL,
    `LastName` VARCHAR(50) NOT NULL,
    `MiddleName` VARCHAR(50) NULL,
    `DepartmentId` INT NULL,
    `IsActive` BOOLEAN NOT NULL DEFAULT 1,
    `IsLocked` BOOLEAN NOT NULL DEFAULT 0,
    `LastLoginDate` DATETIME NULL,
    `FailedLoginAttempts` INT NOT NULL DEFAULT 0,
    `CreatedBy` VARCHAR(100) NOT NULL,
    `CreatedDate` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `ModifiedBy` VARCHAR(100) NULL,
    `ModifiedDate` DATETIME NULL,
    PRIMARY KEY (`UserId`),
    UNIQUE KEY `UK_Users_Username` (`Username`),
    UNIQUE KEY `UK_Users_Email` (`Email`),
    INDEX `IX_Users_Active` (`IsActive`),
    CONSTRAINT `FK_Users_Department` FOREIGN KEY (`DepartmentId`)
        REFERENCES `Departments` (`DepartmentId`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- Table: Roles
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS `Roles`;
CREATE TABLE `Roles` (
    `RoleId` INT AUTO_INCREMENT NOT NULL,
    `RoleName` VARCHAR(50) NOT NULL,
    `Description` VARCHAR(255) NULL,
    `IsActive` BOOLEAN NOT NULL DEFAULT 1,
    `CreatedBy` VARCHAR(100) NOT NULL,
    `CreatedDate` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `ModifiedBy` VARCHAR(100) NULL,
    `ModifiedDate` DATETIME NULL,
    PRIMARY KEY (`RoleId`),
    UNIQUE KEY `UK_Roles_RoleName` (`RoleName`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- Table: UserRoles
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS `UserRoles`;
CREATE TABLE `UserRoles` (
    `UserRoleId` INT AUTO_INCREMENT NOT NULL,
    `UserId` INT NOT NULL,
    `RoleId` INT NOT NULL,
    `AssignedBy` VARCHAR(100) NOT NULL,
    `AssignedDate` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`UserRoleId`),
    UNIQUE KEY `UK_UserRoles_User_Role` (`UserId`, `RoleId`),
    INDEX `IX_UserRoles_UserId` (`UserId`),
    INDEX `IX_UserRoles_RoleId` (`RoleId`),
    CONSTRAINT `FK_UserRoles_User` FOREIGN KEY (`UserId`)
        REFERENCES `Users` (`UserId`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `FK_UserRoles_Role` FOREIGN KEY (`RoleId`)
        REFERENCES `Roles` (`RoleId`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- Table: AuditLogs
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS `AuditLogs`;
CREATE TABLE `AuditLogs` (
    `AuditLogId` BIGINT AUTO_INCREMENT NOT NULL,
    `UserId` INT NULL,
    `Username` VARCHAR(50) NOT NULL,
    `Action` VARCHAR(50) NOT NULL,
    `TableName` VARCHAR(100) NULL,
    `RecordId` VARCHAR(50) NULL,
    `OldValues` LONGTEXT NULL,
    `NewValues` LONGTEXT NULL,
    `IpAddress` VARCHAR(45) NULL,
    `UserAgent` VARCHAR(500) NULL,
    `ActionDate` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`AuditLogId`),
    INDEX `IX_AuditLogs_UserId` (`UserId`),
    INDEX `IX_AuditLogs_Action` (`Action`),
    INDEX `IX_AuditLogs_Table` (`TableName`),
    INDEX `IX_AuditLogs_Date` (`ActionDate`),
    CONSTRAINT `FK_AuditLogs_User` FOREIGN KEY (`UserId`)
        REFERENCES `Users` (`UserId`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- Table: AccountTypes
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS `AccountTypes`;
CREATE TABLE `AccountTypes` (
    `AccountTypeId` INT AUTO_INCREMENT NOT NULL,
    `TypeCode` VARCHAR(20) NOT NULL,
    `TypeName` VARCHAR(50) NOT NULL,
    `NormalBalance` VARCHAR(10) NOT NULL,
    `Category` VARCHAR(50) NOT NULL,
    `DisplayOrder` INT NOT NULL DEFAULT 0,
    `IsActive` BOOLEAN NOT NULL DEFAULT 1,
    `CreatedBy` VARCHAR(100) NOT NULL,
    `CreatedDate` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `ModifiedBy` VARCHAR(100) NULL,
    `ModifiedDate` DATETIME NULL,
    PRIMARY KEY (`AccountTypeId`),
    UNIQUE KEY `UK_AccountTypes_Code` (`TypeCode`),
    INDEX `IX_AccountTypes_Category` (`Category`),
    CONSTRAINT `CK_AccountTypes_NormalBalance` CHECK (`NormalBalance` IN ('DEBIT', 'CREDIT')),
    CONSTRAINT `CK_AccountTypes_Category` CHECK (`Category` IN ('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- Table: ChartOfAccounts
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS `ChartOfAccounts`;
CREATE TABLE `ChartOfAccounts` (
    `AccountId` INT AUTO_INCREMENT NOT NULL,
    `AccountCode` VARCHAR(50) NOT NULL,
    `AccountName` VARCHAR(200) NOT NULL,
    `AccountTypeId` INT NOT NULL,
    `ParentAccountId` INT NULL,
    `Description` VARCHAR(500) NULL,
    `IsHeader` BOOLEAN NOT NULL DEFAULT 0,
    `IsActive` BOOLEAN NOT NULL DEFAULT 1,
    `AllowManualEntry` BOOLEAN NOT NULL DEFAULT 1,
    `Level` INT NOT NULL DEFAULT 1,
    `DepartmentId` INT NULL,
    `OpeningBalance` DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    `OpeningBalanceDate` DATE NULL,
    `CreatedBy` VARCHAR(100) NOT NULL,
    `CreatedDate` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `ModifiedBy` VARCHAR(100) NULL,
    `ModifiedDate` DATETIME NULL,
    PRIMARY KEY (`AccountId`),
    UNIQUE KEY `UK_ChartOfAccounts_Code` (`AccountCode`),
    INDEX `IX_ChartOfAccounts_Type` (`AccountTypeId`),
    INDEX `IX_ChartOfAccounts_Parent` (`ParentAccountId`),
    INDEX `IX_ChartOfAccounts_Active` (`IsActive`),
    INDEX `IX_ChartOfAccounts_Header` (`IsHeader`),
    INDEX `IX_ChartOfAccounts_Department` (`DepartmentId`),
    CONSTRAINT `FK_ChartOfAccounts_AccountType` FOREIGN KEY (`AccountTypeId`)
        REFERENCES `AccountTypes` (`AccountTypeId`) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `FK_ChartOfAccounts_Parent` FOREIGN KEY (`ParentAccountId`)
        REFERENCES `ChartOfAccounts` (`AccountId`) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `FK_ChartOfAccounts_Department` FOREIGN KEY (`DepartmentId`)
        REFERENCES `Departments` (`DepartmentId`) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT `CK_ChartOfAccounts_Level` CHECK (`Level` > 0 AND `Level` <= 10)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- Table: FiscalYears
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS `FiscalYears`;
CREATE TABLE `FiscalYears` (
    `FiscalYearId` INT AUTO_INCREMENT NOT NULL,
    `FiscalYearCode` VARCHAR(20) NOT NULL,
    `FiscalYearName` VARCHAR(100) NOT NULL,
    `StartDate` DATE NOT NULL,
    `EndDate` DATE NOT NULL,
    `IsClosed` BOOLEAN NOT NULL DEFAULT 0,
    `IsActive` BOOLEAN NOT NULL DEFAULT 1,
    `ClosedBy` VARCHAR(100) NULL,
    `ClosedDate` DATETIME NULL,
    `CreatedBy` VARCHAR(100) NOT NULL,
    `CreatedDate` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `ModifiedBy` VARCHAR(100) NULL,
    `ModifiedDate` DATETIME NULL,
    PRIMARY KEY (`FiscalYearId`),
    UNIQUE KEY `UK_FiscalYears_Code` (`FiscalYearCode`),
    INDEX `IX_FiscalYears_Dates` (`StartDate`, `EndDate`),
    INDEX `IX_FiscalYears_Active` (`IsActive`),
    INDEX `IX_FiscalYears_Closed` (`IsClosed`),
    CONSTRAINT `CK_FiscalYears_Dates` CHECK (`EndDate` > `StartDate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- Table: FiscalPeriods
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS `FiscalPeriods`;
CREATE TABLE `FiscalPeriods` (
    `FiscalPeriodId` INT AUTO_INCREMENT NOT NULL,
    `FiscalYearId` INT NOT NULL,
    `PeriodCode` VARCHAR(20) NOT NULL,
    `PeriodName` VARCHAR(100) NOT NULL,
    `PeriodType` VARCHAR(20) NOT NULL DEFAULT 'MONTHLY',
    `StartDate` DATE NOT NULL,
    `EndDate` DATE NOT NULL,
    `PeriodNumber` INT NOT NULL,
    `IsClosed` BOOLEAN NOT NULL DEFAULT 0,
    `IsActive` BOOLEAN NOT NULL DEFAULT 1,
    `ClosedBy` VARCHAR(100) NULL,
    `ClosedDate` DATETIME NULL,
    `CreatedBy` VARCHAR(100) NOT NULL,
    `CreatedDate` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `ModifiedBy` VARCHAR(100) NULL,
    `ModifiedDate` DATETIME NULL,
    PRIMARY KEY (`FiscalPeriodId`),
    UNIQUE KEY `UK_FiscalPeriods_Year_Code` (`FiscalYearId`, `PeriodCode`),
    INDEX `IX_FiscalPeriods_Dates` (`StartDate`, `EndDate`),
    INDEX `IX_FiscalPeriods_Number` (`PeriodNumber`),
    INDEX `IX_FiscalPeriods_Closed` (`IsClosed`),
    INDEX `IX_FiscalPeriods_Active` (`IsActive`),
    CONSTRAINT `FK_FiscalPeriods_FiscalYear` FOREIGN KEY (`FiscalYearId`)
        REFERENCES `FiscalYears` (`FiscalYearId`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `CK_FiscalPeriods_Dates` CHECK (`EndDate` > `StartDate`),
    CONSTRAINT `CK_FiscalPeriods_Type` CHECK (`PeriodType` IN ('MONTHLY', 'QUARTERLY', 'SEMI-ANNUAL', 'ANNUAL'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- Table: AccountBalances
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS `AccountBalances`;
CREATE TABLE `AccountBalances` (
    `AccountBalanceId` BIGINT AUTO_INCREMENT NOT NULL,
    `AccountId` INT NOT NULL,
    `FiscalPeriodId` INT NOT NULL,
    `OpeningBalance` DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    `DebitAmount` DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    `CreditAmount` DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    `ClosingBalance` DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    `LastUpdated` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`AccountBalanceId`),
    UNIQUE KEY `UK_AccountBalances` (`AccountId`, `FiscalPeriodId`),
    INDEX `IX_AccountBalances_Account` (`AccountId`),
    INDEX `IX_AccountBalances_Period` (`FiscalPeriodId`),
    INDEX `IX_AccountBalances_Updated` (`LastUpdated`),
    CONSTRAINT `FK_AccountBalances_Account` FOREIGN KEY (`AccountId`)
        REFERENCES `ChartOfAccounts` (`AccountId`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `FK_AccountBalances_Period` FOREIGN KEY (`FiscalPeriodId`)
        REFERENCES `FiscalPeriods` (`FiscalPeriodId`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- Table: JournalEntryTypes
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS `JournalEntryTypes`;
CREATE TABLE `JournalEntryTypes` (
    `JournalEntryTypeId` INT AUTO_INCREMENT NOT NULL,
    `TypeCode` VARCHAR(20) NOT NULL,
    `TypeName` VARCHAR(100) NOT NULL,
    `Description` VARCHAR(255) NULL,
    `IsActive` BOOLEAN NOT NULL DEFAULT 1,
    `CreatedBy` VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    `CreatedDate` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `ModifiedBy` VARCHAR(100) NULL,
    `ModifiedDate` DATETIME NULL,
    PRIMARY KEY (`JournalEntryTypeId`),
    UNIQUE KEY `UK_JournalEntryTypes_Code` (`TypeCode`),
    INDEX `IX_JournalEntryTypes_Active` (`IsActive`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- Table: JournalEntries
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS `JournalEntries`;
CREATE TABLE `JournalEntries` (
    `JournalEntryId` INT AUTO_INCREMENT NOT NULL,
    `JournalNumber` VARCHAR(30) NOT NULL,
    `FiscalPeriodId` INT NOT NULL,
    `EntryDate` DATE NOT NULL,
    `PostingDate` DATE NULL,
    `JournalEntryTypeId` INT NOT NULL,
    `SourceModule` VARCHAR(30) NOT NULL DEFAULT 'GL',
    `SourceReference` VARCHAR(100) NULL,
    `Description` VARCHAR(500) NOT NULL,
    `Status` VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
    `TotalDebit` DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    `TotalCredit` DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    `PostedBy` VARCHAR(100) NULL,
    `PostedDate` DATETIME NULL,
    `ReversalOfJournalEntryId` INT NULL,
    `CreatedBy` VARCHAR(100) NOT NULL,
    `CreatedDate` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `ModifiedBy` VARCHAR(100) NULL,
    `ModifiedDate` DATETIME NULL,
    PRIMARY KEY (`JournalEntryId`),
    UNIQUE KEY `UK_JournalEntries_Number` (`JournalNumber`),
    INDEX `IX_JournalEntries_Period` (`FiscalPeriodId`),
    INDEX `IX_JournalEntries_Date` (`EntryDate`),
    INDEX `IX_JournalEntries_Type` (`JournalEntryTypeId`),
    INDEX `IX_JournalEntries_Status` (`Status`),
    INDEX `IX_JournalEntries_Source` (`SourceModule`, `SourceReference`),
    CONSTRAINT `FK_JournalEntries_FiscalPeriod` FOREIGN KEY (`FiscalPeriodId`)
        REFERENCES `FiscalPeriods` (`FiscalPeriodId`) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `FK_JournalEntries_Type` FOREIGN KEY (`JournalEntryTypeId`)
        REFERENCES `JournalEntryTypes` (`JournalEntryTypeId`) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `FK_JournalEntries_Reversal` FOREIGN KEY (`ReversalOfJournalEntryId`)
        REFERENCES `JournalEntries` (`JournalEntryId`) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT `CK_JournalEntries_Status` CHECK (`Status` IN ('DRAFT', 'SUBMITTED', 'POSTED', 'REVERSED', 'VOID')),
    CONSTRAINT `CK_JournalEntries_DebitsPositive` CHECK (`TotalDebit` >= 0),
    CONSTRAINT `CK_JournalEntries_CreditsPositive` CHECK (`TotalCredit` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- Table: JournalEntryLines
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS `JournalEntryLines`;
CREATE TABLE `JournalEntryLines` (
    `JournalEntryLineId` BIGINT AUTO_INCREMENT NOT NULL,
    `JournalEntryId` INT NOT NULL,
    `LineNumber` INT NOT NULL,
    `AccountId` INT NOT NULL,
    `DepartmentId` INT NULL,
    `DebitAmount` DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    `CreditAmount` DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    `Description` VARCHAR(500) NULL,
    `ReferenceNumber` VARCHAR(50) NULL,
    `CreatedBy` VARCHAR(100) NOT NULL,
    `CreatedDate` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `ModifiedBy` VARCHAR(100) NULL,
    `ModifiedDate` DATETIME NULL,
    PRIMARY KEY (`JournalEntryLineId`),
    UNIQUE KEY `UK_JournalEntryLines_Line` (`JournalEntryId`, `LineNumber`),
    INDEX `IX_JournalEntryLines_Account` (`AccountId`),
    INDEX `IX_JournalEntryLines_Department` (`DepartmentId`),
    CONSTRAINT `FK_JournalEntryLines_JournalEntry` FOREIGN KEY (`JournalEntryId`)
        REFERENCES `JournalEntries` (`JournalEntryId`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `FK_JournalEntryLines_Account` FOREIGN KEY (`AccountId`)
        REFERENCES `ChartOfAccounts` (`AccountId`) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `FK_JournalEntryLines_Department` FOREIGN KEY (`DepartmentId`)
        REFERENCES `Departments` (`DepartmentId`) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT `CK_JournalEntryLines_AmountsPositive` CHECK (`DebitAmount` >= 0 AND `CreditAmount` >= 0),
    CONSTRAINT `CK_JournalEntryLines_DebitOrCredit` CHECK ((`DebitAmount` > 0 AND `CreditAmount` = 0) OR (`CreditAmount` > 0 AND `DebitAmount` = 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- Sequence Simulation Table (Replaces MSSQL seq_JournalEntryNumber)
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS `JournalEntrySequence`;
CREATE TABLE `JournalEntrySequence` (
    `Id` INT NOT NULL,
    `CurrentValue` BIGINT NOT NULL,
    PRIMARY KEY (`Id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `JournalEntrySequence` (`Id`, `CurrentValue`) VALUES (1, 0)
ON DUPLICATE KEY UPDATE `Id` = `Id`;

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================================
-- 2. FUNCTIONS
-- ============================================================================

DELIMITER $$

-- Function: fn_GetAccountHierarchyPath
DROP FUNCTION IF EXISTS `fn_GetAccountHierarchyPath`$$
CREATE FUNCTION `fn_GetAccountHierarchyPath`(p_AccountId INT)
RETURNS VARCHAR(1000)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_Path VARCHAR(1000) DEFAULT '';
    DECLARE v_CurrentAccountId INT DEFAULT p_AccountId;
    DECLARE v_CurrentCode VARCHAR(50);
    DECLARE v_ParentId INT;
    DECLARE v_Level INT DEFAULT 0;
    DECLARE v_MaxLevel INT DEFAULT 10;

    WHILE v_CurrentAccountId IS NOT NULL AND v_Level < v_MaxLevel DO
        SET v_CurrentCode = NULL;
        SET v_ParentId = NULL;

        SELECT AccountCode, ParentAccountId
        INTO v_CurrentCode, v_ParentId
        FROM ChartOfAccounts
        WHERE AccountId = v_CurrentAccountId
        LIMIT 1;

        IF v_CurrentCode IS NOT NULL THEN
            IF v_Path = '' THEN
                SET v_Path = v_CurrentCode;
            ELSE
                SET v_Path = CONCAT(v_CurrentCode, ' > ', v_Path);
            END IF;
        END IF;

        SET v_CurrentAccountId = v_ParentId;
        SET v_Level = v_Level + 1;
    END WHILE;

    RETURN v_Path;
END$$

-- Function: fn_GetCurrentFiscalPeriod
DROP FUNCTION IF EXISTS `fn_GetCurrentFiscalPeriod`$$
CREATE FUNCTION `fn_GetCurrentFiscalPeriod`()
RETURNS INT
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_CurrentPeriodId INT DEFAULT NULL;

    SELECT FiscalPeriodId INTO v_CurrentPeriodId
    FROM FiscalPeriods
    WHERE CURDATE() BETWEEN StartDate AND EndDate
      AND IsActive = 1
      AND IsClosed = 0
    LIMIT 1;

    IF v_CurrentPeriodId IS NULL THEN
        SELECT FiscalPeriodId INTO v_CurrentPeriodId
        FROM FiscalPeriods
        WHERE IsActive = 1
          AND IsClosed = 0
        ORDER BY StartDate DESC
        LIMIT 1;
    END IF;

    RETURN v_CurrentPeriodId;
END$$

-- Function: fn_AccountHasTransactions
DROP FUNCTION IF EXISTS `fn_AccountHasTransactions`$$
CREATE FUNCTION `fn_AccountHasTransactions`(p_AccountId INT)
RETURNS BOOLEAN
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_HasTransactions BOOLEAN DEFAULT 0;

    IF EXISTS (
        SELECT 1
        FROM AccountBalances
        WHERE AccountId = p_AccountId
          AND (DebitAmount <> 0 OR CreditAmount <> 0)
    ) OR EXISTS (
        SELECT 1
        FROM JournalEntryLines
        WHERE AccountId = p_AccountId
    ) THEN
        SET v_HasTransactions = 1;
    END IF;

    RETURN v_HasTransactions;
END$$

-- Function: fn_GetFiscalYearStatus
DROP FUNCTION IF EXISTS `fn_GetFiscalYearStatus`$$
CREATE FUNCTION `fn_GetFiscalYearStatus`(p_FiscalYearId INT)
RETURNS VARCHAR(20)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_Status VARCHAR(20) DEFAULT 'UNKNOWN';
    DECLARE v_IsClosed BOOLEAN;
    DECLARE v_StartDate DATE;
    DECLARE v_EndDate DATE;

    SELECT IsClosed, StartDate, EndDate
    INTO v_IsClosed, v_StartDate, v_EndDate
    FROM FiscalYears
    WHERE FiscalYearId = p_FiscalYearId
    LIMIT 1;

    IF v_IsClosed IS NULL THEN
        RETURN 'NOT_FOUND';
    END IF;

    IF v_IsClosed = 1 THEN
        SET v_Status = 'CLOSED';
    ELSEIF CURDATE() < v_StartDate THEN
        SET v_Status = 'UPCOMING';
    ELSEIF CURDATE() > v_EndDate THEN
        SET v_Status = 'EXPIRED';
    ELSE
        SET v_Status = 'ACTIVE';
    END IF;

    RETURN v_Status;
END$$

DELIMITER ;

-- ============================================================================
-- 3. VIEWS
-- ============================================================================

-- View: vw_ChartOfAccountsWithDetails
CREATE OR REPLACE VIEW `vw_ChartOfAccountsWithDetails` AS
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
    fn_GetAccountHierarchyPath(coa.AccountId) AS HierarchyPath,
    coa.Description,
    coa.IsHeader,
    coa.IsActive,
    coa.AllowManualEntry,
    coa.Level,
    coa.DepartmentId,
    d.DepartmentName,
    coa.OpeningBalance,
    coa.OpeningBalanceDate,
    fn_AccountHasTransactions(coa.AccountId) AS HasTransactions,
    coa.CreatedBy,
    coa.CreatedDate,
    coa.ModifiedBy,
    coa.ModifiedDate
FROM ChartOfAccounts coa
INNER JOIN AccountTypes at ON coa.AccountTypeId = at.AccountTypeId
LEFT JOIN ChartOfAccounts parent ON coa.ParentAccountId = parent.AccountId
LEFT JOIN Departments d ON coa.DepartmentId = d.DepartmentId;

-- View: vw_FiscalPeriodsWithYearDetails
CREATE OR REPLACE VIEW `vw_FiscalPeriodsWithYearDetails` AS
SELECT
    fp.FiscalPeriodId,
    fp.FiscalYearId,
    fy.FiscalYearCode,
    fy.FiscalYearName,
    fy.IsClosed AS YearIsClosed,
    fn_GetFiscalYearStatus(fy.FiscalYearId) AS YearStatus,
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
        WHEN CURDATE() < fp.StartDate THEN 'UPCOMING'
        WHEN CURDATE() > fp.EndDate THEN 'PAST'
        ELSE 'CURRENT'
    END AS PeriodStatus,
    DATEDIFF(fp.EndDate, fp.StartDate) + 1 AS DaysInPeriod,
    fp.ClosedBy,
    fp.ClosedDate,
    fp.CreatedBy,
    fp.CreatedDate,
    fp.ModifiedBy,
    fp.ModifiedDate
FROM FiscalPeriods fp
INNER JOIN FiscalYears fy ON fp.FiscalYearId = fy.FiscalYearId;

-- View: vw_AccountBalancesSummary
CREATE OR REPLACE VIEW `vw_AccountBalancesSummary` AS
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

-- View: vw_ActiveAccountsHierarchy (MySQL 8.0+ Recursive CTE)
CREATE OR REPLACE VIEW `vw_ActiveAccountsHierarchy` AS
WITH RECURSIVE AccountHierarchy AS (
    SELECT
        AccountId,
        AccountCode,
        AccountName,
        AccountTypeId,
        ParentAccountId,
        IsHeader,
        Level,
        CAST(AccountCode AS CHAR(1000)) AS SortPath,
        0 AS HierarchyLevel
    FROM ChartOfAccounts
    WHERE ParentAccountId IS NULL AND IsActive = 1

    UNION ALL

    SELECT
        c.AccountId,
        c.AccountCode,
        c.AccountName,
        c.AccountTypeId,
        c.ParentAccountId,
        c.IsHeader,
        c.Level,
        CAST(CONCAT(p.SortPath, ' > ', c.AccountCode) AS CHAR(1000)) AS SortPath,
        p.HierarchyLevel + 1 AS HierarchyLevel
    FROM ChartOfAccounts c
    INNER JOIN AccountHierarchy p ON c.ParentAccountId = p.AccountId
    WHERE c.IsActive = 1
)
SELECT
    h.AccountId,
    h.AccountCode,
    h.AccountName,
    at.TypeName AS AccountTypeName,
    at.Category,
    h.IsHeader,
    h.Level,
    h.HierarchyLevel,
    h.SortPath,
    REPEAT('  ', h.HierarchyLevel) AS Indent
FROM AccountHierarchy h
INNER JOIN ChartOfAccounts coa ON h.AccountId = coa.AccountId
INNER JOIN AccountTypes at ON coa.AccountTypeId = at.AccountTypeId;

-- View: vw_JournalEntriesWithDetails
CREATE OR REPLACE VIEW `vw_JournalEntriesWithDetails` AS
SELECT
    je.JournalEntryId,
    je.JournalNumber,
    je.FiscalPeriodId,
    fp.PeriodCode,
    fp.PeriodName,
    fy.FiscalYearCode,
    fp.IsClosed AS PeriodIsClosed,
    je.EntryDate,
    je.PostingDate,
    je.JournalEntryTypeId,
    jet.TypeCode AS EntryTypeCode,
    jet.TypeName AS EntryTypeName,
    je.SourceModule,
    je.SourceReference,
    je.Description,
    je.Status,
    je.TotalDebit,
    je.TotalCredit,
    CASE WHEN je.TotalDebit = je.TotalCredit THEN 1 ELSE 0 END AS IsBalanced,
    je.PostedBy,
    je.PostedDate,
    je.ReversalOfJournalEntryId,
    rev.JournalNumber AS ReversalOfJournalNumber,
    (SELECT COUNT(*) FROM JournalEntryLines jel WHERE jel.JournalEntryId = je.JournalEntryId) AS LineCount,
    je.CreatedBy,
    je.CreatedDate,
    je.ModifiedBy,
    je.ModifiedDate
FROM JournalEntries je
INNER JOIN FiscalPeriods fp ON je.FiscalPeriodId = fp.FiscalPeriodId
INNER JOIN FiscalYears fy ON fp.FiscalYearId = fy.FiscalYearId
INNER JOIN JournalEntryTypes jet ON je.JournalEntryTypeId = jet.JournalEntryTypeId
LEFT JOIN JournalEntries rev ON je.ReversalOfJournalEntryId = rev.JournalEntryId;

-- View: vw_GeneralLedgerDetail
CREATE OR REPLACE VIEW `vw_GeneralLedgerDetail` AS
SELECT
    jel.JournalEntryLineId,
    je.JournalEntryId,
    je.JournalNumber,
    je.EntryDate,
    je.PostingDate,
    je.Status AS JournalStatus,
    je.FiscalPeriodId,
    fp.PeriodCode,
    fp.PeriodName,
    fy.FiscalYearCode,
    jel.LineNumber,
    jel.AccountId,
    coa.AccountCode,
    coa.AccountName,
    at.TypeCode AS AccountTypeCode,
    at.Category AS AccountCategory,
    at.NormalBalance,
    jel.DepartmentId,
    d.DepartmentCode,
    d.DepartmentName,
    jel.DebitAmount,
    jel.CreditAmount,
    CASE
        WHEN at.NormalBalance = 'DEBIT' THEN (jel.DebitAmount - jel.CreditAmount)
        ELSE (jel.CreditAmount - jel.DebitAmount)
    END AS NetAmount,
    jel.Description AS LineDescription,
    jel.ReferenceNumber,
    je.SourceModule,
    je.SourceReference
FROM JournalEntryLines jel
INNER JOIN JournalEntries je ON jel.JournalEntryId = je.JournalEntryId
INNER JOIN FiscalPeriods fp ON je.FiscalPeriodId = fp.FiscalPeriodId
INNER JOIN FiscalYears fy ON fp.FiscalYearId = fy.FiscalYearId
INNER JOIN ChartOfAccounts coa ON jel.AccountId = coa.AccountId
INNER JOIN AccountTypes at ON coa.AccountTypeId = at.AccountTypeId
LEFT JOIN Departments d ON jel.DepartmentId = d.DepartmentId;

-- ============================================================================
-- 4. STORED PROCEDURES
-- ============================================================================

DELIMITER $$

-- SP 1: sp_GetAllChartOfAccounts
DROP PROCEDURE IF EXISTS `sp_GetAllChartOfAccounts`$$
CREATE PROCEDURE `sp_GetAllChartOfAccounts`(
    IN p_IncludeInactive BOOLEAN,
    IN p_AccountTypeId INT,
    IN p_DepartmentId INT
)
BEGIN
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
    WHERE (IFNULL(p_IncludeInactive, FALSE) = TRUE OR coa.IsActive = 1)
      AND (p_AccountTypeId IS NULL OR coa.AccountTypeId = p_AccountTypeId)
      AND (p_DepartmentId IS NULL OR coa.DepartmentId = p_DepartmentId)
    ORDER BY coa.AccountCode;
END$$

-- SP 2: sp_GetChartOfAccountById
DROP PROCEDURE IF EXISTS `sp_GetChartOfAccountById`$$
CREATE PROCEDURE `sp_GetChartOfAccountById`(
    IN p_AccountId INT
)
BEGIN
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
        fn_GetAccountHierarchyPath(coa.AccountId) AS HierarchyPath,
        coa.Description,
        coa.IsHeader,
        coa.IsActive,
        coa.AllowManualEntry,
        coa.Level,
        coa.DepartmentId,
        d.DepartmentName,
        coa.OpeningBalance,
        coa.OpeningBalanceDate,
        fn_AccountHasTransactions(coa.AccountId) AS HasTransactions,
        coa.CreatedBy,
        coa.CreatedDate,
        coa.ModifiedBy,
        coa.ModifiedDate
    FROM ChartOfAccounts coa
    INNER JOIN AccountTypes at ON coa.AccountTypeId = at.AccountTypeId
    LEFT JOIN ChartOfAccounts parent ON coa.ParentAccountId = parent.AccountId
    LEFT JOIN Departments d ON coa.DepartmentId = d.DepartmentId
    WHERE coa.AccountId = p_AccountId;
END$$

-- SP 3: sp_CreateChartOfAccount
DROP PROCEDURE IF EXISTS `sp_CreateChartOfAccount`$$
CREATE PROCEDURE `sp_CreateChartOfAccount`(
    IN p_AccountCode VARCHAR(50),
    IN p_AccountName VARCHAR(200),
    IN p_AccountTypeId INT,
    IN p_ParentAccountId INT,
    IN p_Description VARCHAR(500),
    IN p_IsHeader BOOLEAN,
    IN p_AllowManualEntry BOOLEAN,
    IN p_Level INT,
    IN p_DepartmentId INT,
    IN p_OpeningBalance DECIMAL(18,2),
    IN p_OpeningBalanceDate DATE,
    IN p_CreatedBy VARCHAR(100),
    OUT p_NewAccountId INT
)
BEGIN
    DECLARE v_ParentLevel INT DEFAULT 0;
    DECLARE v_CalculatedLevel INT DEFAULT 1;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF EXISTS (SELECT 1 FROM ChartOfAccounts WHERE AccountCode = p_AccountCode) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Account code already exists.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM AccountTypes WHERE AccountTypeId = p_AccountTypeId) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Account type does not exist.';
    END IF;

    IF p_ParentAccountId IS NOT NULL THEN
        SELECT Level INTO v_ParentLevel
        FROM ChartOfAccounts
        WHERE AccountId = p_ParentAccountId;

        IF v_ParentLevel IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Parent account does not exist.';
        END IF;

        SET v_CalculatedLevel = v_ParentLevel + 1;
        IF v_CalculatedLevel > 10 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Maximum account hierarchy level (10) exceeded.';
        END IF;
    END IF;

    INSERT INTO ChartOfAccounts (
        AccountCode, AccountName, AccountTypeId, ParentAccountId,
        Description, IsHeader, IsActive, AllowManualEntry,
        Level, DepartmentId, OpeningBalance, OpeningBalanceDate,
        CreatedBy, CreatedDate
    ) VALUES (
        p_AccountCode, p_AccountName, p_AccountTypeId, p_ParentAccountId,
        p_Description, IFNULL(p_IsHeader, 0), 1, IFNULL(p_AllowManualEntry, 1),
        v_CalculatedLevel, p_DepartmentId, IFNULL(p_OpeningBalance, 0), p_OpeningBalanceDate,
        p_CreatedBy, NOW()
    );

    SET p_NewAccountId = LAST_INSERT_ID();

    INSERT INTO AuditLogs (Username, Action, TableName, RecordId, NewValues, ActionDate)
    VALUES (
        p_CreatedBy, 'INSERT', 'ChartOfAccounts', CAST(p_NewAccountId AS CHAR(50)),
        CONCAT('{"AccountCode":"', p_AccountCode, '","AccountName":"', p_AccountName, '"}'),
        NOW()
    );

    COMMIT;
END$$

-- SP 4: sp_UpdateChartOfAccount
DROP PROCEDURE IF EXISTS `sp_UpdateChartOfAccount`$$
CREATE PROCEDURE `sp_UpdateChartOfAccount`(
    IN p_AccountId INT,
    IN p_AccountCode VARCHAR(50),
    IN p_AccountName VARCHAR(200),
    IN p_AccountTypeId INT,
    IN p_ParentAccountId INT,
    IN p_Description VARCHAR(500),
    IN p_IsHeader BOOLEAN,
    IN p_AllowManualEntry BOOLEAN,
    IN p_Level INT,
    IN p_DepartmentId INT,
    IN p_OpeningBalance DECIMAL(18,2),
    IN p_OpeningBalanceDate DATE,
    IN p_ModifiedBy VARCHAR(100)
)
BEGIN
    DECLARE v_ParentLevel INT DEFAULT 0;
    DECLARE v_CalculatedLevel INT DEFAULT 1;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM ChartOfAccounts WHERE AccountId = p_AccountId) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Account does not exist.';
    END IF;

    IF EXISTS (SELECT 1 FROM ChartOfAccounts WHERE AccountCode = p_AccountCode AND AccountId <> p_AccountId) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Account code already exists for another account.';
    END IF;

    IF p_ParentAccountId = p_AccountId THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Account cannot be its own parent.';
    END IF;

    IF fn_AccountHasTransactions(p_AccountId) AND EXISTS (
        SELECT 1 FROM ChartOfAccounts WHERE AccountId = p_AccountId AND AccountCode <> p_AccountCode
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Account code cannot be changed after the account has activity.';
    END IF;

    IF p_ParentAccountId IS NOT NULL THEN
        SELECT Level INTO v_ParentLevel FROM ChartOfAccounts WHERE AccountId = p_ParentAccountId;
        SET v_CalculatedLevel = v_ParentLevel + 1;
    END IF;

    UPDATE ChartOfAccounts
    SET
        AccountCode = p_AccountCode,
        AccountName = p_AccountName,
        AccountTypeId = p_AccountTypeId,
        ParentAccountId = p_ParentAccountId,
        Description = p_Description,
        IsHeader = p_IsHeader,
        AllowManualEntry = p_AllowManualEntry,
        Level = v_CalculatedLevel,
        DepartmentId = p_DepartmentId,
        OpeningBalance = p_OpeningBalance,
        OpeningBalanceDate = p_OpeningBalanceDate,
        ModifiedBy = p_ModifiedBy,
        ModifiedDate = NOW()
    WHERE AccountId = p_AccountId;

    INSERT INTO AuditLogs (Username, Action, TableName, RecordId, NewValues, ActionDate)
    VALUES (
        p_ModifiedBy, 'UPDATE', 'ChartOfAccounts', CAST(p_AccountId AS CHAR(50)),
        CONCAT('{"AccountCode":"', p_AccountCode, '","AccountName":"', p_AccountName, '"}'),
        NOW()
    );

    COMMIT;
END$$

-- SP 5: sp_DeleteChartOfAccount
DROP PROCEDURE IF EXISTS `sp_DeleteChartOfAccount`$$
CREATE PROCEDURE `sp_DeleteChartOfAccount`(
    IN p_AccountId INT,
    IN p_DeletedBy VARCHAR(100)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM ChartOfAccounts WHERE AccountId = p_AccountId) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Account does not exist.';
    END IF;

    IF EXISTS (SELECT 1 FROM ChartOfAccounts WHERE ParentAccountId = p_AccountId) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot delete account with child accounts.';
    END IF;

    IF fn_AccountHasTransactions(p_AccountId) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This account cannot be deleted because it has accounting activity.';
    END IF;

    UPDATE ChartOfAccounts
    SET IsActive = 0, ModifiedBy = p_DeletedBy, ModifiedDate = NOW()
    WHERE AccountId = p_AccountId;

    INSERT INTO AuditLogs (Username, Action, TableName, RecordId, ActionDate)
    VALUES (p_DeletedBy, 'DELETE', 'ChartOfAccounts', CAST(p_AccountId AS CHAR(50)), NOW());

    COMMIT;
END$$

-- SP 6: sp_GetAllFiscalYears
DROP PROCEDURE IF EXISTS `sp_GetAllFiscalYears`$$
CREATE PROCEDURE `sp_GetAllFiscalYears`(
    IN p_IncludeInactive BOOLEAN
)
BEGIN
    SELECT
        FiscalYearId,
        FiscalYearCode,
        FiscalYearName,
        StartDate,
        EndDate,
        IsClosed,
        IsActive,
        fn_GetFiscalYearStatus(FiscalYearId) AS Status,
        ClosedBy,
        ClosedDate,
        CreatedBy,
        CreatedDate,
        ModifiedBy,
        ModifiedDate
    FROM FiscalYears
    WHERE (IFNULL(p_IncludeInactive, FALSE) = TRUE OR IsActive = 1)
    ORDER BY StartDate DESC;
END$$

-- SP 7: sp_GetFiscalYearById
DROP PROCEDURE IF EXISTS `sp_GetFiscalYearById`$$
CREATE PROCEDURE `sp_GetFiscalYearById`(
    IN p_FiscalYearId INT
)
BEGIN
    SELECT
        FiscalYearId,
        FiscalYearCode,
        FiscalYearName,
        StartDate,
        EndDate,
        IsClosed,
        IsActive,
        fn_GetFiscalYearStatus(FiscalYearId) AS Status,
        ClosedBy,
        ClosedDate,
        CreatedBy,
        CreatedDate,
        ModifiedBy,
        ModifiedDate
    FROM FiscalYears
    WHERE FiscalYearId = p_FiscalYearId;
END$$

-- SP 8: sp_CreateFiscalYear
DROP PROCEDURE IF EXISTS `sp_CreateFiscalYear`$$
CREATE PROCEDURE `sp_CreateFiscalYear`(
    IN p_FiscalYearCode VARCHAR(20),
    IN p_FiscalYearName VARCHAR(100),
    IN p_StartDate DATE,
    IN p_EndDate DATE,
    IN p_CreatePeriods BOOLEAN,
    IN p_CreatedBy VARCHAR(100),
    OUT p_NewFiscalYearId INT
)
BEGIN
    DECLARE v_MonthCount INT DEFAULT 1;
    DECLARE v_PeriodStart DATE;
    DECLARE v_PeriodEnd DATE;
    DECLARE v_PeriodCode VARCHAR(20);
    DECLARE v_PeriodName VARCHAR(100);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF EXISTS (SELECT 1 FROM FiscalYears WHERE FiscalYearCode = p_FiscalYearCode) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Fiscal year code already exists.';
    END IF;

    IF p_EndDate <= p_StartDate THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'End date must be greater than start date.';
    END IF;

    INSERT INTO FiscalYears (
        FiscalYearCode, FiscalYearName, StartDate, EndDate,
        IsClosed, IsActive, CreatedBy, CreatedDate
    ) VALUES (
        p_FiscalYearCode, p_FiscalYearName, p_StartDate, p_EndDate,
        0, 1, p_CreatedBy, NOW()
    );

    SET p_NewFiscalYearId = LAST_INSERT_ID();

    -- Automatically create 12 monthly periods if requested
    IF IFNULL(p_CreatePeriods, TRUE) = TRUE THEN
        SET v_PeriodStart = p_StartDate;
        WHILE v_MonthCount <= 12 AND v_PeriodStart < p_EndDate DO
            SET v_PeriodEnd = LAST_DAY(v_PeriodStart);
            IF v_PeriodEnd > p_EndDate THEN
                SET v_PeriodEnd = p_EndDate;
            END IF;

            SET v_PeriodCode = CONCAT(p_FiscalYearCode, '-', LPAD(v_MonthCount, 2, '0'));
            SET v_PeriodName = CONCAT(DATE_FORMAT(v_PeriodStart, '%M'), ' ', DATE_FORMAT(v_PeriodStart, '%Y'));

            INSERT INTO FiscalPeriods (
                FiscalYearId, PeriodCode, PeriodName, PeriodType,
                StartDate, EndDate, PeriodNumber, IsClosed, IsActive,
                CreatedBy, CreatedDate
            ) VALUES (
                p_NewFiscalYearId, v_PeriodCode, v_PeriodName, 'MONTHLY',
                v_PeriodStart, v_PeriodEnd, v_MonthCount, 0, 1,
                p_CreatedBy, NOW()
            );

            SET v_PeriodStart = DATE_ADD(v_PeriodEnd, INTERVAL 1 DAY);
            SET v_MonthCount = v_MonthCount + 1;
        END WHILE;
    END IF;

    INSERT INTO AuditLogs (Username, Action, TableName, RecordId, ActionDate)
    VALUES (p_CreatedBy, 'INSERT', 'FiscalYears', CAST(p_NewFiscalYearId AS CHAR(50)), NOW());

    COMMIT;
END$$

-- SP 9: sp_UpdateFiscalYear
DROP PROCEDURE IF EXISTS `sp_UpdateFiscalYear`$$
CREATE PROCEDURE `sp_UpdateFiscalYear`(
    IN p_FiscalYearId INT,
    IN p_FiscalYearCode VARCHAR(20),
    IN p_FiscalYearName VARCHAR(100),
    IN p_StartDate DATE,
    IN p_EndDate DATE,
    IN p_ModifiedBy VARCHAR(100)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM FiscalYears WHERE FiscalYearId = p_FiscalYearId) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Fiscal year does not exist.';
    END IF;

    IF EXISTS (SELECT 1 FROM FiscalYears WHERE FiscalYearCode = p_FiscalYearCode AND FiscalYearId <> p_FiscalYearId) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Fiscal year code already exists for another year.';
    END IF;

    UPDATE FiscalYears
    SET
        FiscalYearCode = p_FiscalYearCode,
        FiscalYearName = p_FiscalYearName,
        StartDate = p_StartDate,
        EndDate = p_EndDate,
        ModifiedBy = p_ModifiedBy,
        ModifiedDate = NOW()
    WHERE FiscalYearId = p_FiscalYearId;

    INSERT INTO AuditLogs (Username, Action, TableName, RecordId, ActionDate)
    VALUES (p_ModifiedBy, 'UPDATE', 'FiscalYears', CAST(p_FiscalYearId AS CHAR(50)), NOW());

    COMMIT;
END$$

-- SP 10: sp_GetAllFiscalPeriods
DROP PROCEDURE IF EXISTS `sp_GetAllFiscalPeriods`$$
CREATE PROCEDURE `sp_GetAllFiscalPeriods`(
    IN p_FiscalYearId INT,
    IN p_IncludeInactive BOOLEAN
)
BEGIN
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
        CASE
            WHEN fp.IsClosed = 1 THEN 'CLOSED'
            WHEN CURDATE() < fp.StartDate THEN 'UPCOMING'
            WHEN CURDATE() > fp.EndDate THEN 'PAST'
            ELSE 'CURRENT'
        END AS Status,
        DATEDIFF(fp.EndDate, fp.StartDate) + 1 AS DaysInPeriod,
        fp.ClosedBy,
        fp.ClosedDate,
        fp.CreatedBy,
        fp.CreatedDate,
        fp.ModifiedBy,
        fp.ModifiedDate
    FROM FiscalPeriods fp
    INNER JOIN FiscalYears fy ON fp.FiscalYearId = fy.FiscalYearId
    WHERE (p_FiscalYearId IS NULL OR fp.FiscalYearId = p_FiscalYearId)
      AND (IFNULL(p_IncludeInactive, FALSE) = TRUE OR fp.IsActive = 1)
    ORDER BY fp.StartDate DESC;
END$$

-- SP 11: sp_CloseFiscalPeriod
DROP PROCEDURE IF EXISTS `sp_CloseFiscalPeriod`$$
CREATE PROCEDURE `sp_CloseFiscalPeriod`(
    IN p_FiscalPeriodId INT,
    IN p_ClosedBy VARCHAR(100)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM FiscalPeriods WHERE FiscalPeriodId = p_FiscalPeriodId) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Fiscal period does not exist.';
    END IF;

    IF EXISTS (SELECT 1 FROM FiscalPeriods WHERE FiscalPeriodId = p_FiscalPeriodId AND IsClosed = 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Fiscal period is already closed.';
    END IF;

    UPDATE FiscalPeriods
    SET
        IsClosed = 1,
        ClosedBy = p_ClosedBy,
        ClosedDate = NOW(),
        ModifiedBy = p_ClosedBy,
        ModifiedDate = NOW()
    WHERE FiscalPeriodId = p_FiscalPeriodId;

    INSERT INTO AuditLogs (Username, Action, TableName, RecordId, ActionDate)
    VALUES (p_ClosedBy, 'CLOSE_PERIOD', 'FiscalPeriods', CAST(p_FiscalPeriodId AS CHAR(50)), NOW());

    COMMIT;
END$$

-- SP 12: sp_GetNextJournalNumber
DROP PROCEDURE IF EXISTS `sp_GetNextJournalNumber`$$
CREATE PROCEDURE `sp_GetNextJournalNumber`(
    OUT p_JournalNumber VARCHAR(30)
)
BEGIN
    DECLARE v_NextVal BIGINT;
    
    UPDATE JournalEntrySequence
    SET CurrentValue = LAST_INSERT_ID(CurrentValue + 1)
    WHERE Id = 1;

    SET v_NextVal = LAST_INSERT_ID();
    SET p_JournalNumber = CONCAT('JE-', YEAR(CURDATE()), '-', LPAD(v_NextVal, 6, '0'));
END$$

-- SP 13: sp_PostJournalEntry
DROP PROCEDURE IF EXISTS `sp_PostJournalEntry`$$
CREATE PROCEDURE `sp_PostJournalEntry`(
    IN p_JournalEntryId INT,
    IN p_PostedBy VARCHAR(100)
)
BEGIN
    DECLARE v_Status VARCHAR(20);
    DECLARE v_FiscalPeriodId INT;
    DECLARE v_LineDebit DECIMAL(18,2) DEFAULT 0.00;
    DECLARE v_LineCredit DECIMAL(18,2) DEFAULT 0.00;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT Status, FiscalPeriodId
    INTO v_Status, v_FiscalPeriodId
    FROM JournalEntries
    WHERE JournalEntryId = p_JournalEntryId
    FOR UPDATE;

    IF v_Status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Journal entry does not exist.';
    END IF;

    IF v_Status = 'POSTED' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Journal entry is already posted.';
    END IF;

    IF v_Status IN ('VOID', 'REVERSED') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot post a journal entry that is VOID or REVERSED.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM JournalEntryLines WHERE JournalEntryId = p_JournalEntryId) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Journal entry must have at least one debit and credit line.';
    END IF;

    SELECT IFNULL(SUM(DebitAmount), 0), IFNULL(SUM(CreditAmount), 0)
    INTO v_LineDebit, v_LineCredit
    FROM JournalEntryLines
    WHERE JournalEntryId = p_JournalEntryId;

    IF v_LineDebit <> v_LineCredit OR v_LineDebit <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Total debits must equal total credits and must be greater than zero.';
    END IF;

    IF EXISTS (SELECT 1 FROM FiscalPeriods WHERE FiscalPeriodId = v_FiscalPeriodId AND IsClosed = 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot post to a closed fiscal period.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM JournalEntryLines jel
        INNER JOIN ChartOfAccounts coa ON jel.AccountId = coa.AccountId
        WHERE jel.JournalEntryId = p_JournalEntryId
          AND (coa.IsHeader = 1 OR coa.IsActive = 0)
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Journal entry lines cannot reference header accounts or inactive accounts.';
    END IF;

    UPDATE JournalEntries
    SET
        Status = 'POSTED',
        PostingDate = CURDATE(),
        PostedBy = p_PostedBy,
        PostedDate = NOW(),
        TotalDebit = v_LineDebit,
        TotalCredit = v_LineCredit,
        ModifiedBy = p_PostedBy,
        ModifiedDate = NOW()
    WHERE JournalEntryId = p_JournalEntryId;

    -- Upsert AccountBalances (MySQL equivalent to MSSQL MERGE)
    INSERT INTO AccountBalances (
        AccountId, FiscalPeriodId, OpeningBalance,
        DebitAmount, CreditAmount, ClosingBalance, LastUpdated
    )
    SELECT
        jel.AccountId,
        v_FiscalPeriodId,
        0.00,
        SUM(jel.DebitAmount),
        SUM(jel.CreditAmount),
        SUM(jel.DebitAmount) - SUM(jel.CreditAmount),
        NOW()
    FROM JournalEntryLines jel
    WHERE jel.JournalEntryId = p_JournalEntryId
    GROUP BY jel.AccountId
    ON DUPLICATE KEY UPDATE
        DebitAmount = AccountBalances.DebitAmount + VALUES(DebitAmount),
        CreditAmount = AccountBalances.CreditAmount + VALUES(CreditAmount),
        ClosingBalance = AccountBalances.OpeningBalance + (AccountBalances.DebitAmount + VALUES(DebitAmount)) - (AccountBalances.CreditAmount + VALUES(CreditAmount)),
        LastUpdated = NOW();

    INSERT INTO AuditLogs (Username, Action, TableName, RecordId, NewValues, ActionDate)
    VALUES (
        p_PostedBy, 'POST', 'JournalEntries', CAST(p_JournalEntryId AS CHAR(50)),
        CONCAT('{"Status":"POSTED","TotalDebit":', v_LineDebit, ',"TotalCredit":', v_LineCredit, '}'),
        NOW()
    );

    COMMIT;
END$$

-- SP 14: sp_ReverseJournalEntry
DROP PROCEDURE IF EXISTS `sp_ReverseJournalEntry`$$
CREATE PROCEDURE `sp_ReverseJournalEntry`(
    IN p_OriginalJournalEntryId INT,
    IN p_ReversalPeriodId INT,
    IN p_ReversalDate DATE,
    IN p_ReversedBy VARCHAR(100),
    OUT p_NewJournalEntryId INT
)
BEGIN
    DECLARE v_OrigStatus VARCHAR(20);
    DECLARE v_OrigNumber VARCHAR(30);
    DECLARE v_OrigDescription VARCHAR(500);
    DECLARE v_OrigTypeId INT;
    DECLARE v_SourceModule VARCHAR(30);
    DECLARE v_TotalDebit DECIMAL(18,2);
    DECLARE v_TotalCredit DECIMAL(18,2);
    DECLARE v_RevTypeId INT;
    DECLARE v_NewJournalNumber VARCHAR(30);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT
        Status, JournalNumber, Description, JournalEntryTypeId,
        SourceModule, TotalDebit, TotalCredit
    INTO
        v_OrigStatus, v_OrigNumber, v_OrigDescription, v_OrigTypeId,
        v_SourceModule, v_TotalDebit, v_TotalCredit
    FROM JournalEntries
    WHERE JournalEntryId = p_OriginalJournalEntryId
    FOR UPDATE;

    IF v_OrigStatus IS NULL OR v_OrigStatus <> 'POSTED' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only POSTED journal entries can be reversed.';
    END IF;

    IF EXISTS (SELECT 1 FROM JournalEntries WHERE ReversalOfJournalEntryId = p_OriginalJournalEntryId) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This journal entry has already been reversed.';
    END IF;

    IF EXISTS (SELECT 1 FROM FiscalPeriods WHERE FiscalPeriodId = p_ReversalPeriodId AND IsClosed = 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Reversal fiscal period is closed.';
    END IF;

    SELECT JournalEntryTypeId INTO v_RevTypeId
    FROM JournalEntryTypes
    WHERE TypeCode = 'REVERSING'
    LIMIT 1;

    IF v_RevTypeId IS NULL THEN
        SET v_RevTypeId = v_OrigTypeId;
    END IF;

    CALL sp_GetNextJournalNumber(v_NewJournalNumber);

    INSERT INTO JournalEntries (
        JournalNumber, FiscalPeriodId, EntryDate,
        JournalEntryTypeId, SourceModule, SourceReference,
        Description, Status, TotalDebit, TotalCredit,
        ReversalOfJournalEntryId, CreatedBy, CreatedDate
    ) VALUES (
        v_NewJournalNumber, p_ReversalPeriodId, p_ReversalDate,
        v_RevTypeId, v_SourceModule, CONCAT('REV:', v_OrigNumber),
        CONCAT('Reversal of ', v_OrigNumber, ': ', v_OrigDescription),
        'DRAFT', v_TotalCredit, v_TotalDebit,
        p_OriginalJournalEntryId, p_ReversedBy, NOW()
    );

    SET p_NewJournalEntryId = LAST_INSERT_ID();

    INSERT INTO JournalEntryLines (
        JournalEntryId, LineNumber, AccountId, DepartmentId,
        DebitAmount, CreditAmount, Description, ReferenceNumber,
        CreatedBy, CreatedDate
    )
    SELECT
        p_NewJournalEntryId, LineNumber, AccountId, DepartmentId,
        CreditAmount, DebitAmount, CONCAT('Reversal: ', IFNULL(Description, '')), ReferenceNumber,
        p_ReversedBy, NOW()
    FROM JournalEntryLines
    WHERE JournalEntryId = p_OriginalJournalEntryId;

    UPDATE JournalEntries
    SET Status = 'REVERSED', ModifiedBy = p_ReversedBy, ModifiedDate = NOW()
    WHERE JournalEntryId = p_OriginalJournalEntryId;

    CALL sp_PostJournalEntry(p_NewJournalEntryId, p_ReversedBy);

    COMMIT;
END$$

DELIMITER ;

-- ============================================================================
-- 5. MASTER / LOOKUP SEED DATA
-- ============================================================================

-- AccountTypes
INSERT INTO `AccountTypes` (`AccountTypeId`, `TypeCode`, `TypeName`, `NormalBalance`, `Category`, `DisplayOrder`, `IsActive`, `CreatedBy`, `CreatedDate`)
VALUES
(1, 'CA', 'Current Assets', 'DEBIT', 'ASSET', 1, 1, 'SYSTEM', NOW()),
(2, 'NCA', 'Non-Current Assets', 'DEBIT', 'ASSET', 2, 1, 'SYSTEM', NOW()),
(3, 'FA', 'Fixed Assets', 'DEBIT', 'ASSET', 3, 1, 'SYSTEM', NOW()),
(4, 'CL', 'Current Liabilities', 'CREDIT', 'LIABILITY', 4, 1, 'SYSTEM', NOW()),
(5, 'NCL', 'Non-Current Liabilities', 'CREDIT', 'LIABILITY', 5, 1, 'SYSTEM', NOW()),
(6, 'EQ', 'Equity', 'CREDIT', 'EQUITY', 6, 1, 'SYSTEM', NOW()),
(7, 'REV', 'Revenue', 'CREDIT', 'REVENUE', 7, 1, 'SYSTEM', NOW()),
(8, 'OREV', 'Other Revenue', 'CREDIT', 'REVENUE', 8, 1, 'SYSTEM', NOW()),
(9, 'OPEX', 'Operating Expenses', 'DEBIT', 'EXPENSE', 9, 1, 'SYSTEM', NOW()),
(10, 'ADMIN', 'Administrative Expenses', 'DEBIT', 'EXPENSE', 10, 1, 'SYSTEM', NOW()),
(11, 'FIN', 'Financial Expenses', 'DEBIT', 'EXPENSE', 11, 1, 'SYSTEM', NOW()),
(12, 'OEXP', 'Other Expenses', 'DEBIT', 'EXPENSE', 12, 1, 'SYSTEM', NOW())
ON DUPLICATE KEY UPDATE `TypeName` = VALUES(`TypeName`);

-- Departments
INSERT INTO `Departments` (`DepartmentId`, `DepartmentCode`, `DepartmentName`, `Description`, `IsActive`, `CreatedBy`, `CreatedDate`)
VALUES
(1, 'ACCT', 'Accounting Department', 'Handles all accounting and financial operations', 1, 'SYSTEM', NOW()),
(2, 'HR', 'Human Resources', 'Manages human resources and payroll', 1, 'SYSTEM', NOW()),
(3, 'IT', 'Information Technology', 'Manages IT systems and infrastructure', 1, 'SYSTEM', NOW()),
(4, 'ADMIN', 'Administration', 'General administration and management', 1, 'SYSTEM', NOW()),
(5, 'ACAD', 'Academic Affairs', 'Academic programs and curriculum', 1, 'SYSTEM', NOW()),
(6, 'REG', 'Registrar Office', 'Student records and enrollment', 1, 'SYSTEM', NOW()),
(7, 'LIB', 'Library Services', 'Library resources and services', 1, 'SYSTEM', NOW())
ON DUPLICATE KEY UPDATE `DepartmentName` = VALUES(`DepartmentName`);

-- Roles
INSERT INTO `Roles` (`RoleId`, `RoleName`, `Description`, `IsActive`, `CreatedBy`, `CreatedDate`)
VALUES
(1, 'Super Admin', 'Full system access with all privileges', 1, 'SYSTEM', NOW()),
(2, 'Finance Director', 'Overall financial management and reporting', 1, 'SYSTEM', NOW()),
(3, 'Chief Accountant', 'Manages accounting operations and approvals', 1, 'SYSTEM', NOW()),
(4, 'Senior Accountant', 'Handles general ledger and financial statements', 1, 'SYSTEM', NOW()),
(5, 'Junior Accountant', 'Data entry and basic accounting tasks', 1, 'SYSTEM', NOW()),
(6, 'Cashier', 'Handles cash transactions and receipts', 1, 'SYSTEM', NOW()),
(7, 'Department Head', 'Departmental budget viewing and approvals', 1, 'SYSTEM', NOW()),
(8, 'Auditor', 'Read-only access for audit purposes', 1, 'SYSTEM', NOW())
ON DUPLICATE KEY UPDATE `RoleName` = VALUES(`RoleName`);

-- Default Admin User (Password: Admin@123)
INSERT INTO `Users` (
    `UserId`, `Username`, `Email`, `PasswordHash`, `PasswordSalt`,
    `FirstName`, `LastName`, `MiddleName`, `DepartmentId`,
    `IsActive`, `IsLocked`, `CreatedBy`, `CreatedDate`
) VALUES (
    1, 'admin', 'admin@valenciacolleges.edu.ph',
    'AQAAAAIAAYagAAAAEPgVw3+yK9L6/p/hH9U+WXZq1Q2j8n7x3q5w4e2r1t0y9u8i7o6p5a4s3d2f1g==',
    'RandomSaltValueForSecurityPurposesOnly1234567890=',
    'System', 'Administrator', 'VCI', 1,
    1, 0, 'SYSTEM', NOW()
) ON DUPLICATE KEY UPDATE `Email` = VALUES(`Email`);

-- UserRoles mapping for Admin
INSERT INTO `UserRoles` (`UserId`, `RoleId`, `AssignedBy`, `AssignedDate`)
VALUES (1, 1, 'SYSTEM', NOW())
ON DUPLICATE KEY UPDATE `AssignedBy` = VALUES(`AssignedBy`);

-- JournalEntryTypes
INSERT INTO `JournalEntryTypes` (`JournalEntryTypeId`, `TypeCode`, `TypeName`, `Description`, `IsActive`, `CreatedBy`)
VALUES
(1, 'MANUAL', 'Manual Journal Entry', 'Standard general journal vouchers entered manually', 1, 'SYSTEM'),
(2, 'ADJUSTING', 'Adjusting Entry', 'Period-end accruals, prepayments, and correction adjustments', 1, 'SYSTEM'),
(3, 'REVERSING', 'Reversing Entry', 'Automatic or manual reversal of accrual journal entries', 1, 'SYSTEM'),
(4, 'CLOSING', 'Closing Entry', 'Year-end revenue and expense closing entries to retained earnings', 1, 'SYSTEM'),
(5, 'AR', 'Accounts Receivable', 'Automated entries generated by student billing and fee collections', 1, 'SYSTEM'),
(6, 'AP', 'Accounts Payable', 'Automated entries generated by vendor invoices and disbursements', 1, 'SYSTEM'),
(7, 'PAYROLL', 'Payroll Entry', 'Automated payroll disbursement and deduction distributions', 1, 'SYSTEM'),
(8, 'DEPRECIATION', 'Depreciation Entry', 'Fixed asset monthly depreciation runs', 1, 'SYSTEM')
ON DUPLICATE KEY UPDATE `TypeName` = VALUES(`TypeName`);

-- ChartOfAccounts Essential Header Structure
INSERT INTO `ChartOfAccounts` (`AccountId`, `AccountCode`, `AccountName`, `AccountTypeId`, `ParentAccountId`, `IsHeader`, `Level`, `OpeningBalance`, `CreatedBy`, `CreatedDate`)
VALUES
(1, '1000', 'ASSETS', 1, NULL, 1, 1, 0.00, 'SYSTEM', NOW()),
(2, '1100', 'Current Assets', 1, 1, 1, 2, 0.00, 'SYSTEM', NOW()),
(3, '1110', 'Cash and Cash Equivalents', 1, 2, 1, 3, 0.00, 'SYSTEM', NOW()),
(4, '1111', 'Cash on Hand', 1, 3, 0, 4, 50000.00, 'SYSTEM', NOW()),
(5, '1112', 'Petty Cash Fund', 1, 3, 0, 4, 20000.00, 'SYSTEM', NOW()),
(6, '2000', 'LIABILITIES', 4, NULL, 1, 1, 0.00, 'SYSTEM', NOW()),
(7, '2100', 'Current Liabilities', 4, 6, 1, 2, 0.00, 'SYSTEM', NOW()),
(8, '3000', 'EQUITY', 6, NULL, 1, 1, 0.00, 'SYSTEM', NOW()),
(9, '4000', 'REVENUE', 7, NULL, 1, 1, 0.00, 'SYSTEM', NOW()),
(10, '5000', 'EXPENSES', 9, NULL, 1, 1, 0.00, 'SYSTEM', NOW())
ON DUPLICATE KEY UPDATE `AccountName` = VALUES(`AccountName`);

-- ============================================================================
-- Migration Complete
-- ============================================================================

