-- =============================================
-- VCI-IAMS Database Creation Script
-- Module: Accounting & Financial Management
-- Version: 1.0
-- Date: August 2026
-- =============================================

USE master;
GO

-- Create database if not exists
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'VCIIAMS')
BEGIN
    CREATE DATABASE VCIIAMS;
    PRINT 'Database VCIIAMS created successfully.';
END
ELSE
BEGIN
    PRINT 'Database VCIIAMS already exists.';
END
GO

USE VCIIAMS;
GO

-- Enable snapshot isolation for better concurrency
ALTER DATABASE VCIIAMS SET ALLOW_SNAPSHOT_ISOLATION ON;
ALTER DATABASE VCIIAMS SET READ_COMMITTED_SNAPSHOT ON;
GO

PRINT 'Database setup completed.';
GO
