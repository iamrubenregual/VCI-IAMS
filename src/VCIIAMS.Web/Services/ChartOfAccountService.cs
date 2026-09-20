using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System.Data;
using Dapper;
using VCIIAMS.Web.Data;
using VCIIAMS.Web.Models;

namespace VCIIAMS.Web.Services
{
    public class ChartOfAccountService : IChartOfAccountService
    {
        private readonly ApplicationDbContext _context;
        private readonly IConfiguration _configuration;
        private readonly string _connectionString;

        public ChartOfAccountService(ApplicationDbContext context, IConfiguration configuration)
        {
            _context = context;
            _configuration = configuration;
            _connectionString = _configuration.GetConnectionString("DefaultConnection")
                ?? throw new InvalidOperationException("Connection string not found.");
        }

        public async Task<IEnumerable<ChartOfAccount>> GetAllAccountsAsync(bool includeInactive = false, int? accountTypeId = null, int? departmentId = null)
        {
            using var connection = new SqlConnection(_connectionString);
            var parameters = new DynamicParameters();
            parameters.Add("@IncludeInactive", includeInactive);
            parameters.Add("@AccountTypeId", accountTypeId);
            parameters.Add("@DepartmentId", departmentId);

            var accounts = await connection.QueryAsync<ChartOfAccount>(
                "sp_GetAllChartOfAccounts",
                parameters,
                commandType: CommandType.StoredProcedure
            );

            return accounts;
        }

        public async Task<ChartOfAccount?> GetAccountByIdAsync(int accountId)
        {
            using var connection = new SqlConnection(_connectionString);
            var parameters = new DynamicParameters();
            parameters.Add("@AccountId", accountId);

            var account = await connection.QueryFirstOrDefaultAsync<ChartOfAccount>(
                "sp_GetChartOfAccountById",
                parameters,
                commandType: CommandType.StoredProcedure
            );

            return account;
        }

        public async Task<ChartOfAccount?> GetAccountByCodeAsync(string accountCode)
        {
            return await _context.ChartOfAccounts
                .Include(a => a.AccountType)
                .Include(a => a.ParentAccount)
                .FirstOrDefaultAsync(a => a.AccountCode == accountCode);
        }

        public async Task<int> CreateAccountAsync(ChartOfAccount account, string createdBy)
        {
            using var connection = new SqlConnection(_connectionString);
            var parameters = new DynamicParameters();
            parameters.Add("@AccountCode", account.AccountCode);
            parameters.Add("@AccountName", account.AccountName);
            parameters.Add("@AccountTypeId", account.AccountTypeId);
            parameters.Add("@ParentAccountId", account.ParentAccountId);
            parameters.Add("@Description", account.Description);
            parameters.Add("@IsHeader", account.IsHeader);
            parameters.Add("@AllowManualEntry", account.AllowManualEntry);
            parameters.Add("@Level", account.Level);
            parameters.Add("@DepartmentId", account.DepartmentId);
            parameters.Add("@OpeningBalance", account.OpeningBalance, DbType.Decimal, ParameterDirection.Input, null, 18, 2);
            parameters.Add("@OpeningBalanceDate", account.OpeningBalanceDate);
            parameters.Add("@CreatedBy", createdBy);
            parameters.Add("@NewAccountId", dbType: DbType.Int32, direction: ParameterDirection.Output);

            await connection.ExecuteAsync(
                "sp_CreateChartOfAccount",
                parameters,
                commandType: CommandType.StoredProcedure
            );

            return parameters.Get<int>("@NewAccountId");
        }

        public async Task<bool> UpdateAccountAsync(ChartOfAccount account, string modifiedBy)
        {
            using var connection = new SqlConnection(_connectionString);
            var parameters = new DynamicParameters();
            parameters.Add("@AccountId", account.AccountId);
            parameters.Add("@AccountCode", account.AccountCode);
            parameters.Add("@AccountName", account.AccountName);
            parameters.Add("@AccountTypeId", account.AccountTypeId);
            parameters.Add("@ParentAccountId", account.ParentAccountId);
            parameters.Add("@Description", account.Description);
            parameters.Add("@IsHeader", account.IsHeader);
            parameters.Add("@AllowManualEntry", account.AllowManualEntry);
            parameters.Add("@Level", account.Level);
            parameters.Add("@DepartmentId", account.DepartmentId);
            parameters.Add("@OpeningBalance", account.OpeningBalance, DbType.Decimal, ParameterDirection.Input, null, 18, 2);
            parameters.Add("@OpeningBalanceDate", account.OpeningBalanceDate);
            parameters.Add("@ModifiedBy", modifiedBy);
            parameters.Add("@ReturnValue", dbType: DbType.Int32, direction: ParameterDirection.ReturnValue);

            await connection.ExecuteAsync(
                "sp_UpdateChartOfAccount",
                parameters,
                commandType: CommandType.StoredProcedure
            );

            return parameters.Get<int>("@ReturnValue") == 0;
        }

        public async Task<bool> DeleteAccountAsync(int accountId, string deletedBy)
        {
            using var connection = new SqlConnection(_connectionString);
            var parameters = new DynamicParameters();
            parameters.Add("@AccountId", accountId);
            parameters.Add("@DeletedBy", deletedBy);
            parameters.Add("@ReturnValue", dbType: DbType.Int32, direction: ParameterDirection.ReturnValue);

            await connection.ExecuteAsync(
                "sp_DeleteChartOfAccount",
                parameters,
                commandType: CommandType.StoredProcedure
            );

            return parameters.Get<int>("@ReturnValue") == 0;
        }

        public async Task<IEnumerable<AccountType>> GetAllAccountTypesAsync()
        {
            return await _context.AccountTypes
                .Where(at => at.IsActive)
                .OrderBy(at => at.DisplayOrder)
                .ToListAsync();
        }

        public async Task<IEnumerable<ChartOfAccount>> GetHeaderAccountsAsync()
        {
            return await _context.ChartOfAccounts
                .Include(a => a.AccountType)
                .Where(a => a.IsHeader && a.IsActive)
                .OrderBy(a => a.AccountCode)
                .ToListAsync();
        }

        public async Task<IEnumerable<ChartOfAccount>> GetChildAccountsAsync(int parentAccountId)
        {
            return await _context.ChartOfAccounts
                .Include(a => a.AccountType)
                .Where(a => a.ParentAccountId == parentAccountId && a.IsActive)
                .OrderBy(a => a.AccountCode)
                .ToListAsync();
        }

        public async Task<bool> AccountCodeExistsAsync(string accountCode, int? excludeAccountId = null)
        {
            var query = _context.ChartOfAccounts.Where(a => a.AccountCode == accountCode);

            if (excludeAccountId.HasValue)
            {
                query = query.Where(a => a.AccountId != excludeAccountId.Value);
            }

            return await query.AnyAsync();
        }
    }
}
