# VCI-IAMS Implementation Guide
## Phase 1: Chart of Accounts & Fiscal Periods

### Files Created

#### Database Scripts (Execute in Order)
1. **01_CreateDatabase.sql** - Creates VCIIAMS database
2. **02_CreateCoreTables.sql** - Core tables (Users, Departments, Roles, AuditLogs)
3. **03_CreateAccountingTables.sql** - Accounting tables (AccountTypes, ChartOfAccounts, FiscalYears, FiscalPeriods, AccountBalances)
4. **04_CreateStoredProcedures.sql** - All CRUD stored procedures
5. **05_CreateFunctionsAndViews.sql** - Database functions and views
6. **06_SeedData.sql** - Initial data (account types, sample COA, departments, roles, admin user)

#### C# Application Structure

**Project File**
- `VCIIAMS.Web.csproj` - Project configuration with NuGet packages

**Configuration**
- `appsettings.json` - Application settings and connection string
- `Program.cs` - Application entry point and service configuration

**Data Layer**
- `Data/ApplicationDbContext.cs` - Entity Framework DbContext

**Models (Entities)**
- `Models/AccountType.cs` - Account type entity
- `Models/ChartOfAccount.cs` - Chart of accounts entity
- `Models/FiscalYear.cs` - Fiscal year entity
- `Models/FiscalPeriod.cs` - Fiscal period entity

**Services (Business Logic)**
- `Services/IChartOfAccountService.cs` - COA service interface
- `Services/ChartOfAccountService.cs` - COA service implementation
- `Services/IFiscalPeriodService.cs` - Fiscal period service interface
- `Services/FiscalPeriodService.cs` - Fiscal period service implementation

**Controllers**
- `Controllers/ChartOfAccountsController.cs` - COA MVC controller
- `Controllers/FiscalPeriodsController.cs` - Fiscal periods MVC controller

### Implementation Steps

#### Step 1: Database Setup
```bash
# Connect to SQL Server and execute scripts
sqlcmd -S localhost -i Database/01_CreateDatabase.sql
sqlcmd -S localhost -d VCIIAMS -i Database/02_CreateCoreTables.sql
sqlcmd -S localhost -d VCIIAMS -i Database/03_CreateAccountingTables.sql
sqlcmd -S localhost -d VCIIAMS -i Database/04_CreateStoredProcedures.sql
sqlcmd -S localhost -d VCIIAMS -i Database/05_CreateFunctionsAndViews.sql
sqlcmd -S localhost -d VCIIAMS -i Database/06_SeedData.sql
```

Or use SQL Server Management Studio:
1. Open SSMS
2. Connect to your SQL Server instance
3. Open and execute each script in order
4. Verify tables, stored procedures, and functions are created

#### Step 2: Application Configuration
1. Navigate to `src/VCIIAMS.Web/`
2. Update `appsettings.json` with your connection string:
```json
"DefaultConnection": "Server=YOUR_SERVER;Database=VCIIAMS;User Id=YOUR_USER;Password=YOUR_PASSWORD;TrustServerCertificate=True;MultipleActiveResultSets=true"
```

#### Step 3: Build and Run
```bash
cd src/VCIIAMS.Web
dotnet restore
dotnet build
dotnet run
```

### API Endpoints Reference

#### Chart of Accounts
- `GET /ChartOfAccounts` - List all accounts
- `GET /ChartOfAccounts/Details/{id}` - View account details
- `GET /ChartOfAccounts/Create` - Create form
- `POST /ChartOfAccounts/Create` - Create account
- `GET /ChartOfAccounts/Edit/{id}` - Edit form
- `POST /ChartOfAccounts/Edit/{id}` - Update account
- `POST /ChartOfAccounts/Delete/{id}` - Delete account

#### Fiscal Periods
- `GET /FiscalPeriods` - List fiscal years
- `GET /FiscalPeriods/Details/{id}` - View year with periods
- `GET /FiscalPeriods/CreateYear` - Create year form
- `POST /FiscalPeriods/CreateYear` - Create fiscal year
- `GET /FiscalPeriods/EditYear/{id}` - Edit year form
- `POST /FiscalPeriods/EditYear/{id}` - Update fiscal year
- `POST /FiscalPeriods/CloseYear/{id}` - Close fiscal year
- `POST /FiscalPeriods/ClosePeriod/{id}` - Close fiscal period
- `GET /FiscalPeriods/Periods` - List all periods

### Database Schema Reference

#### ChartOfAccounts Table
```sql
- AccountId (PK, INT, Identity)
- AccountCode (NVARCHAR(50), Unique, Required)
- AccountName (NVARCHAR(200), Required)
- AccountTypeId (FK to AccountTypes)
- ParentAccountId (FK to ChartOfAccounts, nullable)
- Description (NVARCHAR(500), nullable)
- IsHeader (BIT) - True for grouping accounts
- IsActive (BIT) - Soft delete flag
- AllowManualEntry (BIT) - Can transactions be posted directly
- Level (INT) - Hierarchy depth
- DepartmentId (FK to Departments, nullable)
- OpeningBalance (DECIMAL(18,2))
- OpeningBalanceDate (DATE, nullable)
- CreatedBy, CreatedDate, ModifiedBy, ModifiedDate
```

#### FiscalYears Table
```sql
- FiscalYearId (PK, INT, Identity)
- FiscalYearCode (NVARCHAR(20), Unique, Required)
- FiscalYearName (NVARCHAR(100), Required)
- StartDate (DATE, Required)
- EndDate (DATE, Required)
- IsClosed (BIT)
- IsActive (BIT)
- ClosedBy, ClosedDate
- CreatedBy, CreatedDate, ModifiedBy, ModifiedDate
```

#### FiscalPeriods Table
```sql
- FiscalPeriodId (PK, INT, Identity)
- FiscalYearId (FK to FiscalYears)
- PeriodCode (NVARCHAR(20), Required)
- PeriodName (NVARCHAR(100), Required)
- PeriodType (NVARCHAR(20)) - MONTHLY, QUARTERLY, etc.
- StartDate (DATE, Required)
- EndDate (DATE, Required)
- PeriodNumber (INT)
- IsClosed (BIT)
- IsActive (BIT)
- ClosedBy, ClosedDate
- CreatedBy, CreatedDate, ModifiedBy, ModifiedDate
```

### Key Stored Procedures

**Chart of Accounts**
- `sp_GetAllChartOfAccounts` - Returns all accounts with filters
- `sp_GetChartOfAccountById` - Returns single account
- `sp_CreateChartOfAccount` - Creates new account with validation
- `sp_UpdateChartOfAccount` - Updates account with audit
- `sp_DeleteChartOfAccount` - Soft deletes account

**Fiscal Periods**
- `sp_GetAllFiscalYears` - Returns all fiscal years
- `sp_GetFiscalYearById` - Returns single fiscal year
- `sp_CreateFiscalYear` - Creates year + auto-generates periods
- `sp_UpdateFiscalYear` - Updates fiscal year
- `sp_GetAllFiscalPeriods` - Returns periods with optional filters
- `sp_CloseFiscalPeriod` - Closes a period

### Testing Checklist

#### Chart of Accounts
- [ ] Create root level account (e.g., 1000 ASSETS)
- [ ] Create child account under parent
- [ ] Edit account details
- [ ] Verify account code uniqueness
- [ ] Verify parent-child relationships display correctly
- [ ] Test soft delete functionality
- [ ] Verify audit logs are created

#### Fiscal Periods
- [ ] Create fiscal year with auto-period generation
- [ ] Verify 12 monthly periods are created
- [ ] Edit fiscal year details
- [ ] Close a fiscal period
- [ ] Verify cannot edit closed periods
- [ ] Close fiscal year
- [ ] Test date overlap validation

### Troubleshooting

#### Connection Issues
- Verify SQL Server is running
- Check connection string format
- Ensure database VCIIAMS exists
- Verify user credentials have proper permissions

#### Stored Procedure Errors
- Check if all scripts executed successfully
- Verify stored procedures exist: `SELECT * FROM sys.procedures`
- Check for compilation errors in SQL Server

#### Application Errors
- Check logs in console output
- Verify NuGet packages are restored
- Ensure .NET 8.0 SDK is installed
- Check `appsettings.json` configuration

### Next Development Steps

1. **Create Views** - Need to create Razor views for the controllers
2. **Add Authentication** - Implement user login/authentication
3. **Add Authorization** - Role-based access control
4. **Enhance UI** - Add Bootstrap styling and responsive design
5. **Add Validation** - Client-side validation with jQuery
6. **Add Reports** - Chart of accounts report, fiscal calendar
7. **Add Tests** - Unit tests and integration tests

### Security Considerations

✅ **Implemented**
- Parameterized queries (SQL injection prevention)
- Stored procedures for database operations
- Audit logging for all changes
- Soft delete (data preservation)
- Foreign key constraints

⚠️ **To Implement**
- User authentication and authorization
- Password hashing (BCrypt or PBKDF2)
- CSRF token validation
- Input sanitization
- Role-based access control
- Session management
- HTTPS enforcement in production

### Performance Optimization

✅ **Implemented**
- Database indexes on key columns
- Efficient foreign key relationships
- Stored procedures for complex queries
- Connection string with MultipleActiveResultSets

⚠️ **Future Enhancements**
- Response caching
- Database query optimization
- Lazy loading configuration
- Redis caching for frequently accessed data

---

**Document Version**: 1.0  
**Last Updated**: August 2026  
**Next Review**: After Phase 1 completion
