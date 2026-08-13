# VCI-IAMS Troubleshooting Guide

## Common Issues and Solutions

### Issue: 'TypeName' does not contain a definition

**Solution:** ✅ FIXED - Added all missing [NotMapped] properties to models:
- `ChartOfAccount.cs` - Added TypeName, TypeCode, Category, NormalBalance, DepartmentName, etc.
- `FiscalPeriod.cs` - Added FiscalYearCode, YearIsClosed, YearStatus, PeriodStatus

These properties are populated by stored procedures but need to be defined in the model.

### Issue: Connection String Error

**Problem:** Cannot connect to SQL Server

**Solution:**
1. Update `appsettings.json` with your SQL Server connection string:
```json
"ConnectionStrings": {
  "DefaultConnection": "Server=localhost;Database=VCIIAMS;User Id=sa;Password=YourPassword;TrustServerCertificate=True;MultipleActiveResultSets=true"
}
```

For Windows Authentication:
```json
"DefaultConnection": "Server=localhost;Database=VCIIAMS;Integrated Security=True;TrustServerCertificate=True;MultipleActiveResultSets=true"
```

### Issue: Database Does Not Exist

**Problem:** Database 'VCIIAMS' not found

**Solution:**
Run all SQL scripts in order:
```bash
# In SQL Server Management Studio or Azure Data Studio:
1. 01_CreateDatabase.sql
2. 02_CreateCoreTables.sql
3. 03_CreateAccountingTables.sql
4. 04_CreateStoredProcedures.sql
5. 05_CreateFunctionsAndViews.sql
6. 06_SeedData.sql
```

Or run the master script:
```bash
MASTER_INSTALL.sql
```

### Issue: Stored Procedure Not Found

**Problem:** Could not find stored procedure 'sp_GetAllChartOfAccounts'

**Solution:**
1. Verify stored procedures exist:
```sql
SELECT * FROM sys.procedures WHERE name LIKE 'sp_%'
```

2. If missing, run:
```bash
04_CreateStoredProcedures.sql
```

### Issue: .NET SDK Not Found

**Problem:** 'dotnet' is not recognized

**Solution:**
1. Install .NET 8.0 SDK from: https://dotnet.microsoft.com/download/dotnet/8.0
2. Verify installation:
```bash
dotnet --version
```

### Issue: NuGet Package Restore Failed

**Problem:** Package restore errors

**Solution:**
```bash
cd src/VCIIAMS.Web
dotnet restore --force
dotnet clean
dotnet build
```

### Issue: Port Already in Use

**Problem:** Port 5001 or 5000 is already in use

**Solution:**
1. Edit `launchSettings.json` (if it exists) or
2. Run with different port:
```bash
dotnet run --urls "https://localhost:7001;http://localhost:7000"
```

### Issue: Sidebar Not Toggling

**Problem:** Clicking hamburger menu doesn't collapse sidebar

**Solution:**
1. Check browser console for JavaScript errors
2. Clear browser cache (Ctrl+F5)
3. Verify `site.js` is loaded:
```html
View page source → Check for /js/site.js
```

### Issue: Styles Not Loading

**Problem:** Page looks unstyled, plain HTML

**Solution:**
1. Check if `site.css` exists in `wwwroot/css/`
2. Clear browser cache
3. Check browser console for 404 errors
4. Verify path in _Layout.cshtml:
```html
<link rel="stylesheet" href="~/css/site.css" asp-append-version="true" />
```

### Issue: Validation Not Working

**Problem:** Form validation messages don't appear

**Solution:**
1. Verify jQuery and validation scripts are included:
```html
@section Scripts {
    @{ await Html.RenderPartialAsync("_ValidationScriptsPartial"); }
}
```

2. Check `_ValidationScriptsPartial.cshtml` exists in `Views/Shared/`

### Issue: Default Admin Login Not Working

**Problem:** Cannot login with admin/Admin@123

**Solution:**
1. Verify seed data was run:
```sql
SELECT * FROM Users WHERE Username = 'admin'
```

2. If no results, run:
```bash
06_SeedData.sql
```

**Note:** Authentication is not yet implemented. This is just the default user in database.

### Issue: Bootstrap Icons Not Showing

**Problem:** Icons appear as squares or not at all

**Solution:**
1. Check internet connection (icons load from CDN)
2. Or download Bootstrap Icons and reference locally:
```html
<link rel="stylesheet" href="~/lib/bootstrap-icons/bootstrap-icons.css" />
```

### Issue: Views Not Found (404)

**Problem:** Controller action works but view returns 404

**Solution:**
1. Verify view file exists in correct location:
```
Views/{ControllerName}/{ActionName}.cshtml
```

2. Check file name matches action name exactly (case-sensitive on Linux)

3. Verify `_ViewStart.cshtml` exists in `Views/` folder

### Issue: Stored Procedure Returns No Data

**Problem:** Tables exist but queries return empty

**Solution:**
Run seed data script:
```bash
06_SeedData.sql
```

This creates:
- 12 Account Types
- 75+ Sample Accounts
- 7 Departments
- 8 Roles
- 1 Admin User

### Build and Run Checklist

✅ **Before Running:**
1. SQL Server is running
2. Database VCIIAMS exists
3. All tables created
4. Stored procedures created
5. Seed data loaded
6. Connection string updated in appsettings.json
7. .NET 8.0 SDK installed

✅ **Build Steps:**
```bash
cd src/VCIIAMS.Web
dotnet restore
dotnet build
```

✅ **Run Application:**
```bash
dotnet run
```

✅ **Verify:**
1. Navigate to https://localhost:5001
2. Dashboard loads
3. Sidebar toggles
4. Navigate to Chart of Accounts
5. Create a test account
6. Navigate to Fiscal Periods
7. Create a test fiscal year

### Performance Tips

1. **Slow Queries:**
   - Ensure indexes are created (automatically done by scripts)
   - Check SQL Server performance monitor

2. **Slow Page Load:**
   - Enable response compression
   - Enable static file caching
   - Minimize CSS/JS (for production)

3. **Memory Issues:**
   - Increase SQL Server memory allocation
   - Check for memory leaks in application

### Debugging Tips

1. **Enable Detailed Errors:**
```csharp
// In Program.cs, for development only:
app.UseDeveloperExceptionPage();
```

2. **Check Logs:**
```bash
dotnet run --verbosity detailed
```

3. **SQL Profiler:**
   - Use SQL Server Profiler to see actual queries
   - Check for slow stored procedures

4. **Browser DevTools:**
   - F12 → Console for JavaScript errors
   - Network tab for failed requests
   - Elements tab to inspect CSS

### Getting Help

1. Check this troubleshooting guide
2. Review README.md
3. Review IMPLEMENTATION_GUIDE.md
4. Check PROJECT_SUMMARY.md
5. Review database verification script: `00_VerifyInstallation.sql`

### Quick Verification Script

Run this in SQL Server to verify everything:
```bash
USE VCIIAMS;
:r 00_VerifyInstallation.sql
```

This checks:
- Database exists
- All tables created
- Stored procedures exist
- Functions exist
- Views exist
- Seed data loaded

### Emergency Reset

If everything is broken, start fresh:

1. **Drop Database:**
```sql
DROP DATABASE VCIIAMS;
```

2. **Run All Scripts Again:**
```bash
01_CreateDatabase.sql
02_CreateCoreTables.sql
03_CreateAccountingTables.sql
04_CreateStoredProcedures.sql
05_CreateFunctionsAndViews.sql
06_SeedData.sql
```

3. **Rebuild Application:**
```bash
cd src/VCIIAMS.Web
dotnet clean
dotnet restore
dotnet build
dotnet run
```

---

## Still Having Issues?

1. Check that models have all [NotMapped] properties defined
2. Verify stored procedure returns match model properties
3. Check browser console for errors
4. Check application logs
5. Verify all files are in correct locations

**Remember:** The application works with the provided code. Most issues are configuration or missing steps.
