# VCI Integrated Administrative Management System (VCI-IAMS)

## Phase 1: Accounting & Financial Management - Chart of Accounts & Fiscal Periods

### Overview
This is the first implementation phase of the VCI-IAMS project for Valencia Colleges (Bukidnon), Inc. This phase establishes the foundational accounting structures including Chart of Accounts and Fiscal Periods management.

### Technology Stack
- **Backend**: C# / ASP.NET Core 8.0 MVC
- **Database**: Microsoft SQL Server
- **ORM**: Entity Framework Core 8.0
- **Data Access**: Dapper (for stored procedures)
- **UI Framework**: Bootstrap 5 (responsive web design)

### Project Structure
```
VCI-IAMS/
├── Database/
│   ├── 01_CreateDatabase.sql          - Database creation
│   ├── 02_CreateCoreTables.sql        - Core/shared tables
│   ├── 03_CreateAccountingTables.sql  - Accounting specific tables
│   ├── 04_CreateStoredProcedures.sql  - CRUD stored procedures
│   ├── 05_CreateFunctionsAndViews.sql - Database functions and views
│   └── 06_SeedData.sql                - Initial seed data
└── src/
    └── VCIIAMS.Web/
        ├── Controllers/               - MVC Controllers
        ├── Models/                    - Entity models
        ├── Services/                  - Business logic layer
        ├── Data/                      - DbContext
        └── Views/                     - Razor views
```

### Database Setup

#### 1. Execute SQL Scripts in Order
Run the following scripts in SQL Server Management Studio (SSMS) or Azure Data Studio in sequence.

#### 2. Default Admin Credentials
After running the seed script:
- **Username**: `admin`
- **Password**: `Admin@123`
- **⚠️ CHANGE THIS PASSWORD IMMEDIATELY IN PRODUCTION**

### Features Implemented

#### Chart of Accounts Management
✅ Hierarchical account structure with parent-child relationships  
✅ Account type classification (Asset, Liability, Equity, Revenue, Expense)  
✅ Header accounts for grouping and detail accounts  
✅ Opening balance tracking  
✅ Complete CRUD operations via stored procedures  
✅ Audit logging for all changes  

#### Fiscal Periods Management
✅ Fiscal year creation with automatic period generation  
✅ Monthly, quarterly, and custom period support  
✅ Period opening and closing functionality  
✅ Date range validation and overlapping prevention  
✅ Complete CRUD operations via stored procedures  
✅ Audit logging for all changes  

### Running the Application

#### Prerequisites
- .NET 8.0 SDK
- SQL Server 2019 or later
- Visual Studio 2022 or VS Code

#### Steps
1. Run all database scripts in the Database folder (in order)
2. Update connection string in `appsettings.json`
3. Run `dotnet restore` in the src/VCIIAMS.Web folder
4. Run `dotnet run` to start the application
5. Navigate to `https://localhost:5001`


---

**Project**: VCI-IAMS  
**Client**: Valencia Colleges (Bukidnon), Inc.  
**Phase**: 1 - Accounting & Financial Management  
**Version**: 1.0.0  
**Date**: August 2026
