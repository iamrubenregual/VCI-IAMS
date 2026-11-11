using VCIIAMS.Web.Models;

namespace VCIIAMS.Web.Services
{
    public interface IJournalEntryService
    {
        Task<IEnumerable<JournalEntry>> GetJournalEntriesAsync(
            int? fiscalPeriodId = null,
            string? status = null,
            int? journalEntryTypeId = null,
            DateTime? fromDate = null,
            DateTime? toDate = null,
            string? searchTerm = null);

        Task<JournalEntry?> GetJournalEntryByIdAsync(int journalEntryId);
        Task<JournalEntry?> GetJournalEntryByNumberAsync(string journalNumber);
        Task<string> GenerateNextJournalNumberAsync();
        Task<int> CreateJournalEntryAsync(JournalEntry entry, string createdBy);
        Task<bool> UpdateJournalEntryAsync(JournalEntry entry, string modifiedBy);
        Task<(bool Success, string Message)> PostJournalEntryAsync(int journalEntryId, string postedBy);
        Task<(bool Success, string Message, int? NewEntryId)> ReverseJournalEntryAsync(int originalEntryId, int reversalPeriodId, DateTime reversalDate, string reversedBy);
        Task<(bool Success, string Message)> VoidJournalEntryAsync(int journalEntryId, string voidedBy);
        Task<bool> DeleteDraftJournalEntryAsync(int journalEntryId);

        Task<IEnumerable<JournalEntryType>> GetJournalEntryTypesAsync();
        Task<IEnumerable<Department>> GetDepartmentsAsync();
        Task<IEnumerable<FiscalPeriod>> GetOpenFiscalPeriodsAsync();
        Task<IEnumerable<JournalEntryLine>> GetGeneralLedgerLinesAsync(int? accountId = null, int? fiscalPeriodId = null, DateTime? fromDate = null, DateTime? toDate = null);
    }
}

