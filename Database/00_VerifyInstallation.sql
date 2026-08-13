-- =============================================
-- VCI-IAMS Database Verification Script
-- Run this script to verify all database objects are created
-- =============================================

USE VCIIAMS;
GO

PRINT '========================================';
PRINT 'VCI-IAMS Database Verification';
PRINT '========================================';
PRINT '';

-- Check Database
PRINT 'Checking Database...';
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'VCIIAMS')
    PRINT '✓ Database VCIIAMS exists';
ELSE
    PRINT '✗ Database VCIIAMS NOT FOUND!';
PRINT '';

-- Check Tables
PRINT 'Checking Tables...';
DECLARE @TableCount INT;

SELECT @TableCount = COUNT(*)
FROM sys.tables
WHERE name IN (
    'Users', 'Roles', 'UserRoles', 'Departments', 'AuditLogs',
    'AccountTypes', 'ChartOfAccounts', 'FiscalYears', 'FiscalPeriods', 'AccountBalances'
);

PRINT 'Expected Tables: 10';
PRINT 'Found Tables: ' + CAST(@TableCount AS VARCHAR(10));

IF @TableCount = 10
    PRINT '✓ All tables created successfully';
ELSE
    PRINT '✗ Some tables are missing!';

-- List all tables
SELECT
    TABLE_NAME as [Table Name],
    (SELECT COUNT(*) FROM sys.columns WHERE object_id = OBJECT_ID(TABLE_SCHEMA + '.' + TABLE_NAME)) as [Column Count]
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;
PRINT '';

-- Check Stored Procedures
PRINT 'Checking Stored Procedures...';
DECLARE @SPCount INT;

SELECT @SPCount = COUNT(*)
FROM sys.procedures
WHERE name LIKE 'sp_%';

PRINT 'Expected Stored Procedures: 11';
PRINT 'Found Stored Procedures: ' + CAST(@SPCount AS VARCHAR(10));

IF @SPCount >= 11
    PRINT '✓ All stored procedures created successfully';
ELSE
    PRINT '✗ Some stored procedures are missing!';

-- List all stored procedures
SELECT
    name as [Stored Procedure Name],
    create_date as [Created Date]
FROM sys.procedures
WHERE name LIKE 'sp_%'
ORDER BY name;
PRINT '';

-- Check Functions
PRINT 'Checking Functions...';
DECLARE @FuncCount INT;

SELECT @FuncCount = COUNT(*)
FROM sys.objects
WHERE type IN ('FN', 'IF', 'TF')
AND name LIKE 'fn_%';

PRINT 'Expected Functions: 4';
PRINT 'Found Functions: ' + CAST(@FuncCount AS VARCHAR(10));

IF @FuncCount >= 4
    PRINT '✓ All functions created successfully';
ELSE
    PRINT '✗ Some functions are missing!';

-- List all functions
SELECT
    name as [Function Name],
    type_desc as [Type],
    create_date as [Created Date]
FROM sys.objects
WHERE type IN ('FN', 'IF', 'TF')
AND name LIKE 'fn_%'
ORDER BY name;
PRINT '';

-- Check Views
PRINT 'Checking Views...';
DECLARE @ViewCount INT;

SELECT @ViewCount = COUNT(*)
FROM sys.views
WHERE name LIKE 'vw_%';

PRINT 'Expected Views: 4';
PRINT 'Found Views: ' + CAST(@ViewCount AS VARCHAR(10));

IF @ViewCount >= 4
    PRINT '✓ All views created successfully';
ELSE
    PRINT '✗ Some views are missing!';

-- List all views
SELECT
    name as [View Name],
    create_date as [Created Date]
FROM sys.views
WHERE name LIKE 'vw_%'
ORDER BY name;
PRINT '';

-- Check Seed Data
PRINT 'Checking Seed Data...';

DECLARE @AccountTypeCount INT, @DepartmentCount INT, @RoleCount INT, @UserCount INT, @COACount INT;

SELECT @AccountTypeCount = COUNT(*) FROM AccountTypes;
SELECT @DepartmentCount = COUNT(*) FROM Departments;
SELECT @RoleCount = COUNT(*) FROM Roles;
SELECT @UserCount = COUNT(*) FROM Users;
SELECT @COACount = COUNT(*) FROM ChartOfAccounts;

PRINT 'Account Types: ' + CAST(@AccountTypeCount AS VARCHAR(10)) + ' (Expected: 12)';
PRINT 'Departments: ' + CAST(@DepartmentCount AS VARCHAR(10)) + ' (Expected: 7)';
PRINT 'Roles: ' + CAST(@RoleCount AS VARCHAR(10)) + ' (Expected: 8)';
PRINT 'Users: ' + CAST(@UserCount AS VARCHAR(10)) + ' (Expected: 1 - admin)';
PRINT 'Chart of Accounts: ' + CAST(@COACount AS VARCHAR(10)) + ' (Expected: 75+)';

IF @AccountTypeCount >= 12 AND @DepartmentCount >= 7 AND @RoleCount >= 8 AND @UserCount >= 1 AND @COACount >= 75
    PRINT '✓ All seed data loaded successfully';
ELSE
    PRINT '✗ Some seed data may be missing!';
PRINT '';

-- Check Indexes
PRINT 'Checking Indexes...';
SELECT
    OBJECT_NAME(i.object_id) as [Table Name],
    i.name as [Index Name],
    i.type_desc as [Index Type]
FROM sys.indexes i
WHERE OBJECT_NAME(i.object_id) IN (
    'ChartOfAccounts', 'AccountTypes', 'FiscalYears', 'FiscalPeriods',
    'Users', 'Departments', 'Roles', 'AuditLogs'
)
AND i.name IS NOT NULL
ORDER BY OBJECT_NAME(i.object_id), i.name;
PRINT '';

-- Check Foreign Keys
PRINT 'Checking Foreign Keys...';
SELECT
    OBJECT_NAME(f.parent_object_id) as [Table Name],
    f.name as [Foreign Key Name],
    OBJECT_NAME(f.referenced_object_id) as [Referenced Table]
FROM sys.foreign_keys f
WHERE OBJECT_NAME(f.parent_object_id) IN (
    'ChartOfAccounts', 'FiscalPeriods', 'AccountBalances', 'UserRoles'
)
ORDER BY OBJECT_NAME(f.parent_object_id);
PRINT '';

-- Test Stored Procedures
PRINT 'Testing Stored Procedures...';
PRINT 'Testing sp_GetAllChartOfAccounts...';
BEGIN TRY
    EXEC sp_GetAllChartOfAccounts @IncludeInactive = 0;
    PRINT '✓ sp_GetAllChartOfAccounts works';
END TRY
BEGIN CATCH
    PRINT '✗ sp_GetAllChartOfAccounts failed: ' + ERROR_MESSAGE();
END CATCH;

PRINT 'Testing sp_GetAllFiscalYears...';
BEGIN TRY
    EXEC sp_GetAllFiscalYears @IncludeInactive = 0;
    PRINT '✓ sp_GetAllFiscalYears works';
END TRY
BEGIN CATCH
    PRINT '✗ sp_GetAllFiscalYears failed: ' + ERROR_MESSAGE();
END CATCH;
PRINT '';

-- Test Functions
PRINT 'Testing Functions...';
PRINT 'Testing fn_GetAccountHierarchyPath...';
BEGIN TRY
    DECLARE @TestPath NVARCHAR(1000);
    SELECT TOP 1 @TestPath = dbo.fn_GetAccountHierarchyPath(AccountId) FROM ChartOfAccounts;
    PRINT '✓ fn_GetAccountHierarchyPath works - Sample: ' + ISNULL(@TestPath, 'NULL');
END TRY
BEGIN CATCH
    PRINT '✗ fn_GetAccountHierarchyPath failed: ' + ERROR_MESSAGE();
END CATCH;

PRINT 'Testing fn_GetCurrentFiscalPeriod...';
BEGIN TRY
    DECLARE @CurrentPeriod INT;
    SELECT @CurrentPeriod = dbo.fn_GetCurrentFiscalPeriod();
    PRINT '✓ fn_GetCurrentFiscalPeriod works - Current Period ID: ' + ISNULL(CAST(@CurrentPeriod AS VARCHAR(10)), 'NULL');
END TRY
BEGIN CATCH
    PRINT '✗ fn_GetCurrentFiscalPeriod failed: ' + ERROR_MESSAGE();
END CATCH;
PRINT '';

-- Test Views
PRINT 'Testing Views...';
PRINT 'Testing vw_ChartOfAccountsWithDetails...';
BEGIN TRY
    DECLARE @ViewCount1 INT;
    SELECT @ViewCount1 = COUNT(*) FROM vw_ChartOfAccountsWithDetails;
    PRINT '✓ vw_ChartOfAccountsWithDetails works - Records: ' + CAST(@ViewCount1 AS VARCHAR(10));
END TRY
BEGIN CATCH
    PRINT '✗ vw_ChartOfAccountsWithDetails failed: ' + ERROR_MESSAGE();
END CATCH;
PRINT '';

-- Summary
PRINT '========================================';
PRINT 'VERIFICATION SUMMARY';
PRINT '========================================';
PRINT 'Database: VCIIAMS';
PRINT 'Tables: ' + CAST(@TableCount AS VARCHAR(10)) + '/10';
PRINT 'Stored Procedures: ' + CAST(@SPCount AS VARCHAR(10)) + '/11';
PRINT 'Functions: ' + CAST(@FuncCount AS VARCHAR(10)) + '/4';
PRINT 'Views: ' + CAST(@ViewCount AS VARCHAR(10)) + '/4';
PRINT 'Chart of Accounts: ' + CAST(@COACount AS VARCHAR(10)) + ' records';
PRINT '';

IF @TableCount = 10 AND @SPCount >= 11 AND @FuncCount >= 4 AND @ViewCount >= 4 AND @COACount >= 75
BEGIN
    PRINT '✓✓✓ ALL CHECKS PASSED ✓✓✓';
    PRINT 'VCI-IAMS Database is ready to use!';
    PRINT '';
    PRINT 'Default Admin Credentials:';
    PRINT '  Username: admin';
    PRINT '  Password: Admin@123';
    PRINT '  ⚠️ CHANGE THIS PASSWORD IMMEDIATELY!';
END
ELSE
BEGIN
    PRINT '✗✗✗ SOME CHECKS FAILED ✗✗✗';
    PRINT 'Please review the output above and re-run missing scripts.';
END

PRINT '========================================';
GO
