using VCIIAMS.Web.Models;

namespace VCIIAMS.Web.Services
{
    public interface IFiscalPeriodService
    {
        // Fiscal Years
        Task<IEnumerable<FiscalYear>> GetAllFiscalYearsAsync(bool includeInactive = false);
        Task<FiscalYear?> GetFiscalYearByIdAsync(int fiscalYearId);
        Task<int> CreateFiscalYearAsync(FiscalYear fiscalYear, bool createPeriods, string createdBy);
        Task<bool> UpdateFiscalYearAsync(FiscalYear fiscalYear, string modifiedBy);
        Task<bool> CloseFiscalYearAsync(int fiscalYearId, string closedBy);
        Task<bool> FiscalYearCodeExistsAsync(string fiscalYearCode, int? excludeFiscalYearId = null);

        // Fiscal Periods
        Task<IEnumerable<FiscalPeriod>> GetAllFiscalPeriodsAsync(int? fiscalYearId = null, bool includeInactive = false);
        Task<FiscalPeriod?> GetFiscalPeriodByIdAsync(int fiscalPeriodId);
        Task<FiscalPeriod?> GetCurrentFiscalPeriodAsync();
        Task<bool> CloseFiscalPeriodAsync(int fiscalPeriodId, string closedBy);
        Task<IEnumerable<FiscalPeriod>> GetPeriodsByYearAsync(int fiscalYearId);
    }
}
