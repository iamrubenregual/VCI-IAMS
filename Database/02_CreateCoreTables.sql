-- =============================================
-- Core Administration & Security Tables
-- These tables support all modules
-- =============================================

USE VCIIAMS;
GO

-- =============================================
-- Departments/Offices Table
-- =============================================
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

    PRINT 'Table Departments created successfully.';
END
GO

-- =============================================
-- Users Table
-- =============================================
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

    PRINT 'Table Users created successfully.';
END
GO

-- =============================================
-- Roles Table
-- =============================================
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

    PRINT 'Table Roles created successfully.';
END
GO

-- =============================================
-- UserRoles Table (Many-to-Many)
-- =============================================
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

    PRINT 'Table UserRoles created successfully.';
END
GO

-- =============================================
-- Audit Log Table
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'AuditLogs')
BEGIN
    CREATE TABLE AuditLogs (
        AuditLogId BIGINT IDENTITY(1,1) PRIMARY KEY,
        UserId INT NULL,
        Username NVARCHAR(50) NOT NULL,
        Action NVARCHAR(50) NOT NULL, -- INSERT, UPDATE, DELETE, VIEW, LOGIN, LOGOUT
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

    PRINT 'Table AuditLogs created successfully.';
END
GO

PRINT 'Core tables creation completed.';
GO
