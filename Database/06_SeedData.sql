-- =============================================
-- Seed Data for Initial System Setup
-- =============================================

USE VCIIAMS;
GO

-- =============================================
-- Seed Account Types
-- =============================================
IF NOT EXISTS (SELECT 1 FROM AccountTypes)
BEGIN
    SET IDENTITY_INSERT AccountTypes ON;

    INSERT INTO AccountTypes (AccountTypeId, TypeCode, TypeName, NormalBalance, Category, DisplayOrder, IsActive, CreatedBy, CreatedDate)
    VALUES
    -- Assets
    (1, 'CA', 'Current Assets', 'DEBIT', 'ASSET', 1, 1, 'SYSTEM', GETDATE()),
    (2, 'NCA', 'Non-Current Assets', 'DEBIT', 'ASSET', 2, 1, 'SYSTEM', GETDATE()),
    (3, 'FA', 'Fixed Assets', 'DEBIT', 'ASSET', 3, 1, 'SYSTEM', GETDATE()),

    -- Liabilities
    (4, 'CL', 'Current Liabilities', 'CREDIT', 'LIABILITY', 4, 1, 'SYSTEM', GETDATE()),
    (5, 'NCL', 'Non-Current Liabilities', 'CREDIT', 'LIABILITY', 5, 1, 'SYSTEM', GETDATE()),

    -- Equity
    (6, 'EQ', 'Equity', 'CREDIT', 'EQUITY', 6, 1, 'SYSTEM', GETDATE()),

    -- Revenue
    (7, 'REV', 'Revenue', 'CREDIT', 'REVENUE', 7, 1, 'SYSTEM', GETDATE()),
    (8, 'OREV', 'Other Revenue', 'CREDIT', 'REVENUE', 8, 1, 'SYSTEM', GETDATE()),

    -- Expenses
    (9, 'OPEX', 'Operating Expenses', 'DEBIT', 'EXPENSE', 9, 1, 'SYSTEM', GETDATE()),
    (10, 'ADMIN', 'Administrative Expenses', 'DEBIT', 'EXPENSE', 10, 1, 'SYSTEM', GETDATE()),
    (11, 'FIN', 'Financial Expenses', 'DEBIT', 'EXPENSE', 11, 1, 'SYSTEM', GETDATE()),
    (12, 'OEXP', 'Other Expenses', 'DEBIT', 'EXPENSE', 12, 1, 'SYSTEM', GETDATE());

    SET IDENTITY_INSERT AccountTypes OFF;

    PRINT 'Account types seeded successfully.';
END
ELSE
BEGIN
    PRINT 'Account types already exist. Skipping seed.';
END
GO

-- =============================================
-- Seed Sample Departments
-- =============================================
IF NOT EXISTS (SELECT 1 FROM Departments)
BEGIN
    INSERT INTO Departments (DepartmentCode, DepartmentName, Description, IsActive, CreatedBy, CreatedDate)
    VALUES
    ('ACCT', 'Accounting Department', 'Handles all accounting and financial operations', 1, 'SYSTEM', GETDATE()),
    ('HR', 'Human Resources', 'Manages human resources and payroll', 1, 'SYSTEM', GETDATE()),
    ('IT', 'Information Technology', 'Manages IT systems and infrastructure', 1, 'SYSTEM', GETDATE()),
    ('ADMIN', 'Administration', 'General administration and management', 1, 'SYSTEM', GETDATE()),
    ('ACAD', 'Academic Affairs', 'Academic programs and curriculum', 1, 'SYSTEM', GETDATE()),
    ('REG', 'Registrar', 'Student registration and records', 1, 'SYSTEM', GETDATE()),
    ('CASH', 'Cashier', 'Student payments and cashiering', 1, 'SYSTEM', GETDATE());

    PRINT 'Departments seeded successfully.';
END
ELSE
BEGIN
    PRINT 'Departments already exist. Skipping seed.';
END
GO

-- =============================================
-- Seed Roles
-- =============================================
IF NOT EXISTS (SELECT 1 FROM Roles)
BEGIN
    INSERT INTO Roles (RoleName, Description, IsActive, CreatedBy, CreatedDate)
    VALUES
    ('System Administrator', 'Full system access and administration', 1, 'SYSTEM', GETDATE()),
    ('Accountant', 'Accounting and financial management access', 1, 'SYSTEM', GETDATE()),
    ('Cashier', 'Cashiering and payment processing', 1, 'SYSTEM', GETDATE()),
    ('HR Manager', 'Human resources management', 1, 'SYSTEM', GETDATE()),
    ('Finance Manager', 'Financial oversight and reporting', 1, 'SYSTEM', GETDATE()),
    ('Inventory Manager', 'Inventory and asset management', 1, 'SYSTEM', GETDATE()),
    ('Department Head', 'Department-level access', 1, 'SYSTEM', GETDATE()),
    ('Auditor', 'Read-only access for auditing', 1, 'SYSTEM', GETDATE());

    PRINT 'Roles seeded successfully.';
END
ELSE
BEGIN
    PRINT 'Roles already exist. Skipping seed.';
END
GO

-- =============================================
-- Seed Default Admin User
-- Password: Admin@123 (This should be changed immediately in production)
-- =============================================
IF NOT EXISTS (SELECT 1 FROM Users WHERE Username = 'admin')
BEGIN
    DECLARE @DeptId INT;
    SELECT @DeptId = DepartmentId FROM Departments WHERE DepartmentCode = 'IT';

    INSERT INTO Users (
        Username, Email, PasswordHash, PasswordSalt,
        FirstName, LastName, DepartmentId,
        IsActive, CreatedBy, CreatedDate
    )
    VALUES (
        'admin',
        'admin@vci.edu.ph',
            'AQAAAAMAAYagAAAAENLxkXTcLmcSXWowZ7EufRhzoemrbnZsvlzJu6fF9LDGm1YxiDKXi4AX5ZFOslCz/Q==',
        'RandomSaltValueHere123',
        'System',
        'Administrator',
        @DeptId,
        1,
        'SYSTEM',
        GETDATE()
    );

    -- Assign admin role
    DECLARE @UserId INT = SCOPE_IDENTITY();
    DECLARE @AdminRoleId INT;
    SELECT @AdminRoleId = RoleId FROM Roles WHERE RoleName = 'System Administrator';

    INSERT INTO UserRoles (UserId, RoleId, AssignedBy, AssignedDate)
    VALUES (@UserId, @AdminRoleId, 'SYSTEM', GETDATE());

    PRINT 'Default admin user created successfully.';
    PRINT 'Username: admin';
    PRINT 'Password: Admin@123 (CHANGE IMMEDIATELY IN PRODUCTION)';
END
ELSE
BEGIN
    PRINT 'Admin user already exists. Skipping seed.';
END
GO

-- Repair the original malformed development hash without overwriting a changed password.
UPDATE Users
SET PasswordHash = 'AQAAAAMAAYagAAAAENLxkXTcLmcSXWowZ7EufRhzoemrbnZsvlzJu6fF9LDGm1YxiDKXi4AX5ZFOslCz/Q=='
WHERE Username = 'admin'
  AND PasswordHash = 'AQAAAAEAACcQAAAAEKZxG6JxMpCv8PjKvD7qR6oJ5Gm9TZJ4t/5mK8H3Q2w1N7Y0V9X6z5C4B3A2M1L0';
GO
-- =============================================
-- Seed Sample Chart of Accounts
-- Basic structure for educational institution
-- =============================================
IF NOT EXISTS (SELECT 1 FROM ChartOfAccounts)
BEGIN
    SET IDENTITY_INSERT ChartOfAccounts ON;

    -- ASSETS (1000-1999)
    -- Current Assets
    INSERT INTO ChartOfAccounts (AccountId, AccountCode, AccountName, AccountTypeId, ParentAccountId, IsHeader, Level, OpeningBalance, CreatedBy, CreatedDate)
    VALUES
    (1, '1000', 'ASSETS', 1, NULL, 1, 1, 0, 'SYSTEM', GETDATE()),
    (2, '1100', 'Current Assets', 1, 1, 1, 2, 0, 'SYSTEM', GETDATE()),
    (3, '1110', 'Cash and Cash Equivalents', 1, 2, 1, 3, 0, 'SYSTEM', GETDATE()),
    (4, '1111', 'Cash on Hand', 1, 3, 0, 4, 0, 'SYSTEM', GETDATE()),
    (5, '1112', 'Petty Cash', 1, 3, 0, 4, 0, 'SYSTEM', GETDATE()),
    (6, '1113', 'Cash in Bank - Current Account', 1, 3, 0, 4, 0, 'SYSTEM', GETDATE()),
    (7, '1114', 'Cash in Bank - Savings Account', 1, 3, 0, 4, 0, 'SYSTEM', GETDATE()),

    (8, '1120', 'Accounts Receivable', 1, 2, 1, 3, 0, 'SYSTEM', GETDATE()),
    (9, '1121', 'Student Accounts Receivable', 1, 8, 0, 4, 0, 'SYSTEM', GETDATE()),
    (10, '1122', 'Allowance for Doubtful Accounts', 1, 8, 0, 4, 0, 'SYSTEM', GETDATE()),
    (11, '1123', 'Other Receivables', 1, 8, 0, 4, 0, 'SYSTEM', GETDATE()),

    (12, '1130', 'Prepaid Expenses', 1, 2, 1, 3, 0, 'SYSTEM', GETDATE()),
    (13, '1131', 'Prepaid Insurance', 1, 12, 0, 4, 0, 'SYSTEM', GETDATE()),
    (14, '1132', 'Prepaid Rent', 1, 12, 0, 4, 0, 'SYSTEM', GETDATE()),

    (15, '1140', 'Inventory', 1, 2, 1, 3, 0, 'SYSTEM', GETDATE()),
    (16, '1141', 'Office Supplies Inventory', 1, 15, 0, 4, 0, 'SYSTEM', GETDATE()),
    (17, '1142', 'School Supplies Inventory', 1, 15, 0, 4, 0, 'SYSTEM', GETDATE()),

    -- Fixed Assets
    (18, '1200', 'Fixed Assets', 3, 1, 1, 2, 0, 'SYSTEM', GETDATE()),
    (19, '1210', 'Property and Buildings', 3, 18, 1, 3, 0, 'SYSTEM', GETDATE()),
    (20, '1211', 'Land', 3, 19, 0, 4, 0, 'SYSTEM', GETDATE()),
    (21, '1212', 'Buildings', 3, 19, 0, 4, 0, 'SYSTEM', GETDATE()),
    (22, '1213', 'Accumulated Depreciation - Buildings', 3, 19, 0, 4, 0, 'SYSTEM', GETDATE()),

    (23, '1220', 'Furniture and Equipment', 3, 18, 1, 3, 0, 'SYSTEM', GETDATE()),
    (24, '1221', 'Furniture and Fixtures', 3, 23, 0, 4, 0, 'SYSTEM', GETDATE()),
    (25, '1222', 'Accumulated Depreciation - Furniture', 3, 23, 0, 4, 0, 'SYSTEM', GETDATE()),
    (26, '1223', 'Office Equipment', 3, 23, 0, 4, 0, 'SYSTEM', GETDATE()),
    (27, '1224', 'Accumulated Depreciation - Equipment', 3, 23, 0, 4, 0, 'SYSTEM', GETDATE()),

    (28, '1230', 'Computers and Technology', 3, 18, 1, 3, 0, 'SYSTEM', GETDATE()),
    (29, '1231', 'Computer Equipment', 3, 28, 0, 4, 0, 'SYSTEM', GETDATE()),
    (30, '1232', 'Accumulated Depreciation - Computers', 3, 28, 0, 4, 0, 'SYSTEM', GETDATE()),

    -- LIABILITIES (2000-2999)
    (31, '2000', 'LIABILITIES', 4, NULL, 1, 1, 0, 'SYSTEM', GETDATE()),
    (32, '2100', 'Current Liabilities', 4, 31, 1, 2, 0, 'SYSTEM', GETDATE()),
    (33, '2110', 'Accounts Payable', 4, 32, 1, 3, 0, 'SYSTEM', GETDATE()),
    (34, '2111', 'Accounts Payable - Trade', 4, 33, 0, 4, 0, 'SYSTEM', GETDATE()),
    (35, '2112', 'Accounts Payable - Others', 4, 33, 0, 4, 0, 'SYSTEM', GETDATE()),

    (36, '2120', 'Accrued Expenses', 4, 32, 1, 3, 0, 'SYSTEM', GETDATE()),
    (37, '2121', 'Accrued Salaries and Wages', 4, 36, 0, 4, 0, 'SYSTEM', GETDATE()),
    (38, '2122', 'Accrued Utilities', 4, 36, 0, 4, 0, 'SYSTEM', GETDATE()),

    (39, '2130', 'Deferred Revenue', 4, 32, 1, 3, 0, 'SYSTEM', GETDATE()),
    (40, '2131', 'Unearned Tuition Revenue', 4, 39, 0, 4, 0, 'SYSTEM', GETDATE()),

    (41, '2140', 'Statutory Payables', 4, 32, 1, 3, 0, 'SYSTEM', GETDATE()),
    (42, '2141', 'SSS Payable', 4, 41, 0, 4, 0, 'SYSTEM', GETDATE()),
    (43, '2142', 'PhilHealth Payable', 4, 41, 0, 4, 0, 'SYSTEM', GETDATE()),
    (44, '2143', 'Pag-IBIG Payable', 4, 41, 0, 4, 0, 'SYSTEM', GETDATE()),
    (45, '2144', 'Withholding Tax Payable', 4, 41, 0, 4, 0, 'SYSTEM', GETDATE()),

    -- EQUITY (3000-3999)
    (46, '3000', 'EQUITY', 6, NULL, 1, 1, 0, 'SYSTEM', GETDATE()),
    (47, '3100', 'Capital', 6, 46, 1, 2, 0, 'SYSTEM', GETDATE()),
    (48, '3110', 'Capital Stock', 6, 47, 0, 3, 0, 'SYSTEM', GETDATE()),
    (49, '3120', 'Retained Earnings', 6, 47, 0, 3, 0, 'SYSTEM', GETDATE()),
    (50, '3130', 'Current Year Earnings', 6, 47, 0, 3, 0, 'SYSTEM', GETDATE()),

    -- REVENUE (4000-4999)
    (51, '4000', 'REVENUE', 7, NULL, 1, 1, 0, 'SYSTEM', GETDATE()),
    (52, '4100', 'Tuition and Fees', 7, 51, 1, 2, 0, 'SYSTEM', GETDATE()),
    (53, '4110', 'Tuition Revenue', 7, 52, 0, 3, 0, 'SYSTEM', GETDATE()),
    (54, '4120', 'Laboratory Fees', 7, 52, 0, 3, 0, 'SYSTEM', GETDATE()),
    (55, '4130', 'Miscellaneous Fees', 7, 52, 0, 3, 0, 'SYSTEM', GETDATE()),
    (56, '4140', 'Registration Fees', 7, 52, 0, 3, 0, 'SYSTEM', GETDATE()),

    (57, '4200', 'Other Income', 8, 51, 1, 2, 0, 'SYSTEM', GETDATE()),
    (58, '4210', 'Interest Income', 8, 57, 0, 3, 0, 'SYSTEM', GETDATE()),
    (59, '4220', 'Rental Income', 8, 57, 0, 3, 0, 'SYSTEM', GETDATE()),

    -- EXPENSES (5000-5999)
    (60, '5000', 'EXPENSES', 9, NULL, 1, 1, 0, 'SYSTEM', GETDATE()),
    (61, '5100', 'Personnel Expenses', 9, 60, 1, 2, 0, 'SYSTEM', GETDATE()),
    (62, '5110', 'Salaries and Wages', 9, 61, 0, 3, 0, 'SYSTEM', GETDATE()),
    (63, '5120', 'Employee Benefits', 9, 61, 0, 3, 0, 'SYSTEM', GETDATE()),
    (64, '5130', 'SSS Contribution', 9, 61, 0, 3, 0, 'SYSTEM', GETDATE()),
    (65, '5131', 'PhilHealth Contribution', 9, 61, 0, 3, 0, 'SYSTEM', GETDATE()),
    (66, '5132', 'Pag-IBIG Contribution', 9, 61, 0, 3, 0, 'SYSTEM', GETDATE()),

    (67, '5200', 'Operating Expenses', 9, 60, 1, 2, 0, 'SYSTEM', GETDATE()),
    (68, '5210', 'Rent Expense', 9, 67, 0, 3, 0, 'SYSTEM', GETDATE()),
    (69, '5220', 'Utilities Expense', 9, 67, 0, 3, 0, 'SYSTEM', GETDATE()),
    (70, '5230', 'Office Supplies Expense', 9, 67, 0, 3, 0, 'SYSTEM', GETDATE()),
    (71, '5240', 'Repairs and Maintenance', 9, 67, 0, 3, 0, 'SYSTEM', GETDATE()),
    (72, '5250', 'Insurance Expense', 9, 67, 0, 3, 0, 'SYSTEM', GETDATE()),

    (73, '5300', 'Depreciation Expense', 9, 60, 1, 2, 0, 'SYSTEM', GETDATE()),
    (74, '5310', 'Depreciation - Buildings', 9, 73, 0, 3, 0, 'SYSTEM', GETDATE()),
    (75, '5320', 'Depreciation - Equipment', 9, 73, 0, 3, 0, 'SYSTEM', GETDATE());

    SET IDENTITY_INSERT ChartOfAccounts OFF;

    PRINT 'Sample Chart of Accounts seeded successfully.';
END
ELSE
BEGIN
    PRINT 'Chart of Accounts already exists. Skipping seed.';
END
GO

PRINT 'All seed data completed successfully.';
PRINT '========================================';
PRINT 'IMPORTANT: Default admin credentials:';
PRINT 'Username: admin';
PRINT 'Password: Admin@123';
PRINT 'CHANGE THIS PASSWORD IMMEDIATELY!';
PRINT '========================================';
GO
