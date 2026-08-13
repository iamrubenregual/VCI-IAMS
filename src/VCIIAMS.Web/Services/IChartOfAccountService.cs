using VCIIAMS.Web.Models;

namespace VCIIAMS.Web.Services
{
    public interface IChartOfAccountService
    {
        Task<IEnumerable<ChartOfAccount>> GetAllAccountsAsync(bool includeInactive = false, int? accountTypeId = null, int? departmentId = null);
        Task<ChartOfAccount?> GetAccountByIdAsync(int accountId);
        Task<ChartOfAccount?> GetAccountByCodeAsync(string accountCode);
        Task<int> CreateAccountAsync(ChartOfAccount account, string createdBy);
        Task<bool> UpdateAccountAsync(ChartOfAccount account, string modifiedBy);
        Task<bool> DeleteAccountAsync(int accountId, string deletedBy);
        Task<IEnumerable<AccountType>> GetAllAccountTypesAsync();
        Task<IEnumerable<ChartOfAccount>> GetHeaderAccountsAsync();
        Task<IEnumerable<ChartOfAccount>> GetChildAccountsAsync(int parentAccountId);
        Task<bool> AccountCodeExistsAsync(string accountCode, int? excludeAccountId = null);
    }
}
