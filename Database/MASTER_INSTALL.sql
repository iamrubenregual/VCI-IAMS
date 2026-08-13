-- =============================================
-- VCI-IAMS Master Installation Script
-- This script runs all database scripts in the correct order
-- =============================================
-- INSTRUCTIONS:
-- 1. Open this file in SQL Server Management Studio (SSMS)
-- 2. Make sure you are connected to your SQL Server instance
-- 3. Press F5 or click Execute to run the entire installation
-- 4. Review the output messages for any errors
-- =============================================

PRINT '========================================';
PRINT 'VCI-IAMS DATABASE INSTALLATION';
PRINT 'Valencia Colleges (Bukidnon), Inc.';
PRINT 'Phase 1: Accounting & Financial Management';
PRINT '========================================';
PRINT '';
PRINT 'Installation started at: ' + CONVERT(VARCHAR(20), GETDATE(), 120);
PRINT '';

-- =============================================
-- STEP 1: Create Database
-- =============================================
PRINT '>>> STEP 1: Creating Database...';
PRINT '';

USE master;
GO

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'VCIIAMS')
BEGIN
    CREATE DATABASE VCIIAMS;
    PRINT '✓ Database VCIIAMS created successfully.';
END
ELSE
BEGIN
    PRINT '! Database VCIIAMS already exists. Skipping creation.';
END
GO

USE VCIIAMS;
GO

ALTER DATABASE VCIIAMS SET ALLOW_SNAPSHOT_ISOLATION ON;
ALTER DATABASE VCIIAMS SET READ_COMMITTED_SNAPSHOT ON;
GO

PRINT '✓ Database configuration completed.';
PRINT '';

-- =============================================
-- STEP 2: Create Core Tables
-- =============================================
PRINT '>>> STEP 2: Creating Core Tables...';
PRINT '';

-- Departments Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Departments')
BEGIN
    CREATE TABLE Departments (
        DepartmentId INT IDENTITY(1,1) PRIMARY KEY,
        DepartmentCode NVARCHAR(20) NOT NULL UNIQUE,
        DepartmentName NVARCHAR(100) NOT NULL,
        Description NVARCHAR(500) NULL,
        ParentDepartmentId INT NULL,
        IsActive BIT NOT NULL DEFAULT 1,
        CreatedBy NVARCHAR(100) NOT NULL,
        CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
        ModifiedBy NVARCHAR(100) NULL,
        ModifiedDate DATETIME NULL,
        CONSTRAINT FK_Departments_Parent FOREIGN KEY (ParentDepartmentId)
            REFERENCES Departments(DepartmentId)
    );
    CREATE INDEX IX_Departments_Code ON Departments(DepartmentCode);
    CREATE INDEX IX_Departments_Active ON Departments(IsActive);
    PRINT '✓ Table Departments created.';
END
ELSE
    PRINT '! Table Departments already exists.';
GO

-- Users Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Users')
BEGIN
    CREATE TABLE Users (
        UserId INT IDENTITY(1,1) PRIMARY KEY,
        Username NVARCHAR(50) NOT NULL UNIQUE,
        Email NVARCHAR(100) NOT NULL UNIQUE,
        PasswordHash NVARCHAR(255) NOT NULL,
        PasswordSalt NVARCHAR(255) NOT NULL,
        FirstName NVARCHAR(50) NOT NULL,
        LastName NVARCHAR(50) NOT NULL,
        MiddleName NVARCHAR(50) NULL,
        DepartmentId INT NULL,
        IsActive BIT NOT NULL DEFAULT 1,
        IsLocked BIT NOT NULL DEFAULT 0,
        LastLoginDate DATETIME NULL,
        FailedLoginAttempts INT NOT NULL DEFAULT 0,
        CreatedBy NVARCHAR(100) NOT NULL,
        CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
        ModifiedBy NVARCHAR(100) NULL,
        ModifiedDate DATETIME NULL,
        CONSTRAINT FK_Users_Department FOREIGN KEY (DepartmentId)
            REFERENCES Departments(DepartmentId)
    );
    CREATE INDEX IX_Users_Username ON Users(Username);
    CREATE INDEX IX_Users_Email ON Users(Email);
    CREATE INDEX IX_Users_Active ON Users(IsActive);
    PRINT '✓ Table Users created.';
END
ELSE
    PRINT '! Table Users already exists.';
GO

-- Roles Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Roles')
BEGIN
    CREATE TABLE Roles (
        RoleId INT IDENTITY(1,1) PRIMARY KEY,
        RoleName NVARCHAR(50) NOT NULL UNIQUE,
        Description NVARCHAR(255) NULL,
        IsActive BIT NOT NULL DEFAULT 1,
        CreatedBy NVARCHAR(100) NOT NULL,
        CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
        ModifiedBy NVARCHAR(100) NULL,
        ModifiedDate DATETIME NULL
    );
    CREATE INDEX IX_Roles_Name ON Roles(RoleName);
    PRINT '✓ Table Roles created.';
END
ELSE
    PRINT '! Table Roles already exists.';
GO

-- UserRoles Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'UserRoles')
BEGIN
    CREATE TABLE UserRoles (
        UserRoleId INT IDENTITY(1,1) PRIMARY KEY,
        UserId INT NOT NULL,
        RoleId INT NOT NULL,
        AssignedBy NVARCHAR(100) NOT NULL,
        AssignedDate DATETIME NOT NULL DEFAULT GETDATE(),
        CONSTRAINT FK_UserRoles_User FOREIGN KEY (UserId)
            REFERENCES Users(UserId) ON DELETE CASCADE,
        CONSTRAINT FK_UserRoles_Role FOREIGN KEY (RoleId)
            REFERENCES Roles(RoleId) ON DELETE CASCADE,
        CONSTRAINT UK_UserRoles UNIQUE (UserId, RoleId)
    );
    CREATE INDEX IX_UserRoles_UserId ON UserRoles(UserId);
    CREATE INDEX IX_UserRoles_RoleId ON UserRoles(RoleId);
    PRINT '✓ Table UserRoles created.';
END
ELSE
    PRINT '! Table UserRoles already exists.';
GO

-- AuditLogs Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'AuditLogs')
BEGIN
    CREATE TABLE AuditLogs (
        AuditLogId BIGINT IDENTITY(1,1) PRIMARY KEY,
        UserId INT NULL,
        Username NVARCHAR(50) NOT NULL,
        Action NVARCHAR(50) NOT NULL,
        TableName NVARCHAR(100) NULL,
        RecordId NVARCHAR(50) NULL,
        OldValues NVARCHAR(MAX) NULL,
        NewValues NVARCHAR(MAX) NULL,
        IpAddress NVARCHAR(45) NULL,
        UserAgent NVARCHAR(500) NULL,
        ActionDate DATETIME NOT NULL DEFAULT GETDATE(),
        CONSTRAINT FK_AuditLogs_User FOREIGN KEY (UserId)
            REFERENCES Users(UserId)
    );
    CREATE INDEX IX_AuditLogs_UserId ON AuditLogs(UserId);
    CREATE INDEX IX_AuditLogs_Action ON AuditLogs(Action);
    CREATE INDEX IX_AuditLogs_Table ON AuditLogs(TableName);
    CREATE INDEX IX_AuditLogs_Date ON AuditLogs(ActionDate);
    PRINT '✓ Table AuditLogs created.';
END
ELSE
    PRINT '! Table AuditLogs already exists.';
GO

PRINT '✓ Core tables creation completed.';
PRINT '';

-- =============================================
-- STEP 3: Create Accounting Tables
-- =============================================
PRINT '>>> STEP 3: Creating Accounting Tables...';
PRINT '';

-- NOTE: For brevity, this master script includes just the key commands.
-- For full table creation with all indexes and constraints,
-- run scripts 02 and 03 separately.

-- Run the full scripts
:r 03_CreateAccountingTables.sql

PRINT '✓ Accounting tables creation completed.';
PRINT '';

-- =============================================
-- STEP 4: Create Stored Procedures
-- =============================================
PRINT '>>> STEP 4: Creating Stored Procedures...';
PRINT '';

:r 04_CreateStoredProcedures.sql

PRINT '✓ Stored procedures creation completed.';
PRINT '';

-- =============================================
-- STEP 5: Create Functions and Views
-- =============================================
PRINT '>>> STEP 5: Creating Functions and Views...';
PRINT '';

:r 05_CreateFunctionsAndViews.sql

PRINT '✓ Functions and views creation completed.';
PRINT '';

-- =============================================
-- STEP 6: Load Seed Data
-- =============================================
PRINT '>>> STEP 6: Loading Seed Data...';
PRINT '';

:r 06_SeedData.sql

PRINT '✓ Seed data loading completed.';
PRINT '';

-- =============================================
-- STEP 7: Verification
-- =============================================
PRINT '>>> STEP 7: Running Verification...';
PRINT '';

:r 00_VerifyInstallation.sql

-- =============================================
-- Installation Complete
-- =============================================
PRINT '';
PRINT '========================================';
PRINT 'INSTALLATION COMPLETED';
PRINT '========================================';
PRINT 'Installation completed at: ' + CONVERT(VARCHAR(20), GETDATE(), 120);
PRINT '';
PRINT 'Next Steps:';
PRINT '1. Update connection string in appsettings.json';
PRINT '2. Run: dotnet restore';
PRINT '3. Run: dotnet run';
PRINT '4. Login with default credentials:';
PRINT '   Username: admin';
PRINT '   Password: Admin@123';
PRINT '   ⚠️ CHANGE THIS PASSWORD IMMEDIATELY!';
PRINT '';
PRINT '========================================';
GO
