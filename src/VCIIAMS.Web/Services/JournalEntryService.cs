using Microsoft.EntityFrameworkCore;
using VCIIAMS.Web.Data;
using VCIIAMS.Web.Models;

namespace VCIIAMS.Web.Services
{
    public class JournalEntryService : IJournalEntryService
    {
        private readonly ApplicationDbContext _context;
        private readonly ILogger<JournalEntryService> _logger;

        public JournalEntryService(
            ApplicationDbContext context,
            ILogger<JournalEntryService> logger)
        {
            _context = context;
            _logger = logger;
        }

        public async Task<IEnumerable<JournalEntry>> GetJournalEntriesAsync(
            int? fiscalPeriodId = null,
            string? status = null,
            int? journalEntryTypeId = null,
            DateTime? fromDate = null,
            DateTime? toDate = null,
            string? searchTerm = null)
        {
            var query = _context.JournalEntries
                .Include(j => j.FiscalPeriod)
                    .ThenInclude(p => p!.FiscalYear)
                .Include(j => j.JournalEntryType)
                .Include(j => j.Lines)
                    .ThenInclude(l => l.Account)
                .Include(j => j.ReversalOfJournalEntry)
                .AsNoTracking()
                .AsQueryable();

            if (fiscalPeriodId.HasValue && fiscalPeriodId.Value > 0)
                query = query.Where(j => j.FiscalPeriodId == fiscalPeriodId.Value);

            if (!string.IsNullOrWhiteSpace(status))
                query = query.Where(j => j.Status == status);

            if (journalEntryTypeId.HasValue && journalEntryTypeId.Value > 0)
                query = query.Where(j => j.JournalEntryTypeId == journalEntryTypeId.Value);

            if (fromDate.HasValue)
                query = query.Where(j => j.EntryDate >= fromDate.Value.Date);

            if (toDate.HasValue)
                query = query.Where(j => j.EntryDate <= toDate.Value.Date);

            if (!string.IsNullOrWhiteSpace(searchTerm))
            {
                var term = searchTerm.Trim();
                query = query.Where(j =>
                    j.JournalNumber.Contains(term) ||
                    j.Description.Contains(term) ||
                    (j.SourceReference != null && j.SourceReference.Contains(term)));
            }

            var results = await query.OrderByDescending(j => j.EntryDate)
                                     .ThenByDescending(j => j.JournalEntryId)
                                     .ToListAsync();

            foreach (var item in results)
            {
                item.PeriodCode = item.FiscalPeriod?.PeriodCode;
                item.PeriodName = item.FiscalPeriod?.PeriodName;
                item.FiscalYearCode = item.FiscalPeriod?.FiscalYear?.FiscalYearCode;
                item.EntryTypeCode = item.JournalEntryType?.TypeCode;
                item.EntryTypeName = item.JournalEntryType?.TypeName;
                item.ReversalOfJournalNumber = item.ReversalOfJournalEntry?.JournalNumber;
            }

            return results;
        }

        public async Task<JournalEntry?> GetJournalEntryByIdAsync(int journalEntryId)
        {
            var entry = await _context.JournalEntries
                .Include(j => j.FiscalPeriod)
                    .ThenInclude(p => p!.FiscalYear)
                .Include(j => j.JournalEntryType)
                .Include(j => j.ReversalOfJournalEntry)
                .Include(j => j.Lines)
                    .ThenInclude(l => l.Account)
                        .ThenInclude(a => a!.AccountType)
                .Include(j => j.Lines)
                    .ThenInclude(l => l.Department)
                .AsNoTracking()
                .FirstOrDefaultAsync(j => j.JournalEntryId == journalEntryId);

            if (entry != null)
            {
                entry.PeriodCode = entry.FiscalPeriod?.PeriodCode;
                entry.PeriodName = entry.FiscalPeriod?.PeriodName;
                entry.FiscalYearCode = entry.FiscalPeriod?.FiscalYear?.FiscalYearCode;
                entry.EntryTypeCode = entry.JournalEntryType?.TypeCode;
                entry.EntryTypeName = entry.JournalEntryType?.TypeName;
                entry.ReversalOfJournalNumber = entry.ReversalOfJournalEntry?.JournalNumber;

                // Sort lines by LineNumber
                entry.Lines = entry.Lines.OrderBy(l => l.LineNumber).ToList();
                foreach (var line in entry.Lines)
                {
                    line.AccountCode = line.Account?.AccountCode;
                    line.AccountName = line.Account?.AccountName;
                    line.DepartmentCode = line.Department?.DepartmentCode;
                    line.DepartmentName = line.Department?.DepartmentName;
                }
            }

            return entry;
        }

        public async Task<JournalEntry?> GetJournalEntryByNumberAsync(string journalNumber)
        {
            return await _context.JournalEntries
                .Include(j => j.Lines)
                .AsNoTracking()
                .FirstOrDefaultAsync(j => j.JournalNumber == journalNumber);
        }

        public async Task<string> GenerateNextJournalNumberAsync()
        {
            var year = DateTime.Today.Year;
            var prefix = $"JE-{year}-";

            // Find highest existing number for this year
            var latestEntry = await _context.JournalEntries
                .Where(j => j.JournalNumber.StartsWith(prefix))
                .OrderByDescending(j => j.JournalNumber)
                .Select(j => j.JournalNumber)
                .FirstOrDefaultAsync();

            int nextNum = 1;
            if (!string.IsNullOrEmpty(latestEntry) && latestEntry.Length > prefix.Length)
            {
                var numPart = latestEntry.Substring(prefix.Length);
                if (int.TryParse(numPart, out int currentNum))
                {
                    nextNum = currentNum + 1;
                }
            }

            return $"{prefix}{nextNum:D6}";
        }

        public async Task<int> CreateJournalEntryAsync(JournalEntry entry, string createdBy)
        {
            if (string.IsNullOrWhiteSpace(entry.JournalNumber))
            {
                entry.JournalNumber = await GenerateNextJournalNumberAsync();
            }

            entry.CreatedBy = createdBy;
            entry.CreatedDate = DateTime.Now;
            entry.Status = "DRAFT";

            // Calculate totals
            entry.TotalDebit = entry.Lines.Sum(l => l.DebitAmount);
            entry.TotalCredit = entry.Lines.Sum(l => l.CreditAmount);

            // Assign line numbers and audit info
            int lineNum = 1;
            foreach (var line in entry.Lines)
            {
                line.LineNumber = lineNum++;
                line.CreatedBy = createdBy;
                line.CreatedDate = DateTime.Now;
            }

            _context.JournalEntries.Add(entry);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Created draft journal entry {JournalNumber}", entry.JournalNumber);
            return entry.JournalEntryId;
        }

        public async Task<bool> UpdateJournalEntryAsync(JournalEntry entry, string modifiedBy)
        {
            var existing = await _context.JournalEntries
                .Include(j => j.Lines)
                .FirstOrDefaultAsync(j => j.JournalEntryId == entry.JournalEntryId);

            if (existing == null || existing.Status == "POSTED" || existing.Status == "REVERSED")
                return false;

            existing.FiscalPeriodId = entry.FiscalPeriodId;
            existing.EntryDate = entry.EntryDate;
            existing.JournalEntryTypeId = entry.JournalEntryTypeId;
            existing.SourceModule = entry.SourceModule;
            existing.SourceReference = entry.SourceReference;
            existing.Description = entry.Description;
            existing.ModifiedBy = modifiedBy;
            existing.ModifiedDate = DateTime.Now;

            // Remove existing lines and re-add updated lines
            _context.JournalEntryLines.RemoveRange(existing.Lines);

            int lineNum = 1;
            foreach (var line in entry.Lines)
            {
                line.JournalEntryId = existing.JournalEntryId;
                line.LineNumber = lineNum++;
                line.CreatedBy = existing.CreatedBy;
                line.CreatedDate = existing.CreatedDate;
                line.ModifiedBy = modifiedBy;
                line.ModifiedDate = DateTime.Now;
                _context.JournalEntryLines.Add(line);
            }

            existing.TotalDebit = entry.Lines.Sum(l => l.DebitAmount);
            existing.TotalCredit = entry.Lines.Sum(l => l.CreditAmount);

            await _context.SaveChangesAsync();
            _logger.LogInformation("Updated draft journal entry {JournalNumber}", existing.JournalNumber);
            return true;
        }

        public async Task<(bool Success, string Message)> PostJournalEntryAsync(int journalEntryId, string postedBy)
        {
            using var transaction = await _context.Database.BeginTransactionAsync();
            try
            {
                var entry = await _context.JournalEntries
                    .Include(j => j.FiscalPeriod)
                    .Include(j => j.Lines)
                        .ThenInclude(l => l.Account)
                            .ThenInclude(a => a!.AccountType)
                    .FirstOrDefaultAsync(j => j.JournalEntryId == journalEntryId);

                if (entry == null)
                    return (false, "Journal entry not found.");

                if (entry.Status == "POSTED")
                    return (false, "Journal entry is already posted.");

                if (entry.Status == "VOID" || entry.Status == "REVERSED")
                    return (false, $"Cannot post an entry with status '{entry.Status}'.");

                if (entry.FiscalPeriod == null || entry.FiscalPeriod.IsClosed)
                    return (false, "Cannot post to a closed fiscal period.");

                if (entry.Lines == null || entry.Lines.Count < 2)
                    return (false, "Journal entry must have at least two lines (one debit and one credit).");

                var totalDebit = entry.Lines.Sum(l => l.DebitAmount);
                var totalCredit = entry.Lines.Sum(l => l.CreditAmount);

                if (totalDebit <= 0 || totalCredit <= 0 || totalDebit != totalCredit)
                    return (false, $"Entry is unbalanced. Total Debits: {totalDebit:N2}, Total Credits: {totalCredit:N2}.");

                // Validate no header accounts or inactive accounts
                foreach (var line in entry.Lines)
                {
                    if (line.Account == null)
                        line.Account = await _context.ChartOfAccounts.FindAsync(line.AccountId);

                    if (line.Account == null)
                        return (false, $"Account ID {line.AccountId} does not exist.");

                    if (line.Account.IsHeader)
                        return (false, $"Cannot post to header account '{line.Account.AccountCode} - {line.Account.AccountName}'.");

                    if (!line.Account.IsActive)
                        return (false, $"Cannot post to inactive account '{line.Account.AccountCode} - {line.Account.AccountName}'.");
                }

                // Update entry status
                entry.Status = "POSTED";
                entry.PostingDate = DateTime.Today;
                entry.PostedBy = postedBy;
                entry.PostedDate = DateTime.Now;
                entry.TotalDebit = totalDebit;
                entry.TotalCredit = totalCredit;
                entry.ModifiedBy = postedBy;
                entry.ModifiedDate = DateTime.Now;

                // Update / Upsert AccountBalances
                var groupedByAccount = entry.Lines
                    .GroupBy(l => l.AccountId)
                    .Select(g => new
                    {
                        AccountId = g.Key,
                        Debit = g.Sum(x => x.DebitAmount),
                        Credit = g.Sum(x => x.CreditAmount)
                    });

                foreach (var accGroup in groupedByAccount)
                {
                    var balance = await _context.AccountBalances
                        .FirstOrDefaultAsync(b => b.AccountId == accGroup.AccountId && b.FiscalPeriodId == entry.FiscalPeriodId);

                    if (balance == null)
                    {
                        balance = new AccountBalance
                        {
                            AccountId = accGroup.AccountId,
                            FiscalPeriodId = entry.FiscalPeriodId,
                            OpeningBalance = 0,
                            DebitAmount = accGroup.Debit,
                            CreditAmount = accGroup.Credit,
                            ClosingBalance = accGroup.Debit - accGroup.Credit,
                            LastUpdated = DateTime.Now
                        };
                        _context.AccountBalances.Add(balance);
                    }
                    else
                    {
                        balance.DebitAmount += accGroup.Debit;
                        balance.CreditAmount += accGroup.Credit;
                        balance.ClosingBalance = balance.OpeningBalance + balance.DebitAmount - balance.CreditAmount;
                        balance.LastUpdated = DateTime.Now;
                    }
                }

                await _context.SaveChangesAsync();
                await transaction.CommitAsync();

                _logger.LogInformation("Posted journal entry {JournalNumber} with total {TotalDebit:N2}", entry.JournalNumber, totalDebit);
                return (true, $"Journal entry {entry.JournalNumber} posted successfully.");
            }
            catch (Exception ex)
            {
                await transaction.RollbackAsync();
                _logger.LogError(ex, "Error posting journal entry {Id}", journalEntryId);
                return (false, $"Failed to post entry: {ex.Message}");
            }
        }

        public async Task<(bool Success, string Message, int? NewEntryId)> ReverseJournalEntryAsync(
            int originalEntryId,
            int reversalPeriodId,
            DateTime reversalDate,
            string reversedBy)
        {
            using var transaction = await _context.Database.BeginTransactionAsync();
            try
            {
                var original = await _context.JournalEntries
                    .Include(j => j.Lines)
                    .FirstOrDefaultAsync(j => j.JournalEntryId == originalEntryId);

                if (original == null)
                    return (false, "Original journal entry not found.", null);

                if (original.Status != "POSTED")
                    return (false, "Only POSTED journal entries can be reversed.", null);

                var alreadyReversed = await _context.JournalEntries
                    .AnyAsync(j => j.ReversalOfJournalEntryId == originalEntryId);

                if (alreadyReversed)
                    return (false, $"Journal entry {original.JournalNumber} has already been reversed.", null);

                var targetPeriod = await _context.FiscalPeriods.FindAsync(reversalPeriodId);
                if (targetPeriod == null || targetPeriod.IsClosed)
                    return (false, "Target reversal fiscal period is closed or invalid.", null);

                // Get or default Reversing Type
                var reversingType = await _context.JournalEntryTypes
                    .FirstOrDefaultAsync(t => t.TypeCode == "REVERSING") ?? original.JournalEntryType;

                var newNumber = await GenerateNextJournalNumberAsync();

                var reversalEntry = new JournalEntry
                {
                    JournalNumber = newNumber,
                    FiscalPeriodId = reversalPeriodId,
                    EntryDate = reversalDate,
                    JournalEntryTypeId = reversingType?.JournalEntryTypeId ?? original.JournalEntryTypeId,
                    SourceModule = original.SourceModule,
                    SourceReference = $"REV:{original.JournalNumber}",
                    Description = $"Reversal of {original.JournalNumber}: {original.Description}",
                    Status = "DRAFT",
                    TotalDebit = original.TotalCredit,
                    TotalCredit = original.TotalDebit,
                    ReversalOfJournalEntryId = original.JournalEntryId,
                    CreatedBy = reversedBy,
                    CreatedDate = DateTime.Now
                };

                int lineNum = 1;
                foreach (var line in original.Lines)
                {
                    reversalEntry.Lines.Add(new JournalEntryLine
                    {
                        LineNumber = lineNum++,
                        AccountId = line.AccountId,
                        DepartmentId = line.DepartmentId,
                        DebitAmount = line.CreditAmount, // Swapped
                        CreditAmount = line.DebitAmount, // Swapped
                        Description = $"Reversal: {line.Description}",
                        ReferenceNumber = line.ReferenceNumber,
                        CreatedBy = reversedBy,
                        CreatedDate = DateTime.Now
                    });
                }

                _context.JournalEntries.Add(reversalEntry);

                // Mark original as REVERSED
                original.Status = "REVERSED";
                original.ModifiedBy = reversedBy;
                original.ModifiedDate = DateTime.Now;

                await _context.SaveChangesAsync();
                await transaction.CommitAsync();

                // Post the reversal entry
                var postResult = await PostJournalEntryAsync(reversalEntry.JournalEntryId, reversedBy);
                if (!postResult.Success)
                {
                    return (true, $"Reversal entry {reversalEntry.JournalNumber} created as draft, but posting failed: {postResult.Message}", reversalEntry.JournalEntryId);
                }

                _logger.LogInformation("Reversed journal entry {Original} with new entry {Reversal}", original.JournalNumber, reversalEntry.JournalNumber);
                return (true, $"Journal entry {original.JournalNumber} successfully reversed by {reversalEntry.JournalNumber}.", reversalEntry.JournalEntryId);
            }
            catch (Exception ex)
            {
                await transaction.RollbackAsync();
                _logger.LogError(ex, "Error reversing journal entry {Id}", originalEntryId);
                return (false, $"Failed to reverse journal entry: {ex.Message}", null);
            }
        }

        public async Task<(bool Success, string Message)> VoidJournalEntryAsync(int journalEntryId, string voidedBy)
        {
            var entry = await _context.JournalEntries.FindAsync(journalEntryId);
            if (entry == null)
                return (false, "Journal entry not found.");

            if (entry.Status == "POSTED")
                return (false, "Posted journal entries cannot be voided. Use Reversal instead.");

            if (entry.Status == "VOID")
                return (false, "Journal entry is already voided.");

            entry.Status = "VOID";
            entry.ModifiedBy = voidedBy;
            entry.ModifiedDate = DateTime.Now;

            await _context.SaveChangesAsync();
            _logger.LogInformation("Voided journal entry {JournalNumber}", entry.JournalNumber);
            return (true, $"Journal entry {entry.JournalNumber} has been voided.");
        }

        public async Task<bool> DeleteDraftJournalEntryAsync(int journalEntryId)
        {
            var entry = await _context.JournalEntries
                .Include(j => j.Lines)
                .FirstOrDefaultAsync(j => j.JournalEntryId == journalEntryId);

            if (entry == null || entry.Status != "DRAFT")
                return false;

            _context.JournalEntries.Remove(entry);
            await _context.SaveChangesAsync();
            _logger.LogInformation("Deleted draft journal entry {JournalNumber}", entry.JournalNumber);
            return true;
        }

        public async Task<IEnumerable<JournalEntryType>> GetJournalEntryTypesAsync()
        {
            return await _context.JournalEntryTypes
                .Where(t => t.IsActive)
                .OrderBy(t => t.TypeName)
                .AsNoTracking()
                .ToListAsync();
        }

        public async Task<IEnumerable<Department>> GetDepartmentsAsync()
        {
            return await _context.Departments
                .Where(d => d.IsActive)
                .OrderBy(d => d.DepartmentName)
                .AsNoTracking()
                .ToListAsync();
        }

        public async Task<IEnumerable<FiscalPeriod>> GetOpenFiscalPeriodsAsync()
        {
            return await _context.FiscalPeriods
                .Include(p => p.FiscalYear)
                .Where(p => !p.IsClosed && p.IsActive)
                .OrderByDescending(p => p.StartDate)
                .AsNoTracking()
                .ToListAsync();
        }

        public async Task<IEnumerable<JournalEntryLine>> GetGeneralLedgerLinesAsync(
            int? accountId = null,
            int? fiscalPeriodId = null,
            DateTime? fromDate = null,
            DateTime? toDate = null)
        {
            var query = _context.JournalEntryLines
                .Include(l => l.JournalEntry)
                    .ThenInclude(j => j!.FiscalPeriod)
                        .ThenInclude(p => p!.FiscalYear)
                .Include(l => l.Account)
                    .ThenInclude(a => a!.AccountType)
                .Include(l => l.Department)
                .Where(l => l.JournalEntry!.Status == "POSTED")
                .AsNoTracking()
                .AsQueryable();

            if (accountId.HasValue && accountId.Value > 0)
                query = query.Where(l => l.AccountId == accountId.Value);

            if (fiscalPeriodId.HasValue && fiscalPeriodId.Value > 0)
                query = query.Where(l => l.JournalEntry!.FiscalPeriodId == fiscalPeriodId.Value);

            if (fromDate.HasValue)
                query = query.Where(l => l.JournalEntry!.EntryDate >= fromDate.Value.Date);

            if (toDate.HasValue)
                query = query.Where(l => l.JournalEntry!.EntryDate <= toDate.Value.Date);

            var lines = await query.OrderBy(l => l.JournalEntry!.EntryDate)
                                   .ThenBy(l => l.JournalEntry!.JournalNumber)
                                   .ThenBy(l => l.LineNumber)
                                   .ToListAsync();

            foreach (var line in lines)
            {
                line.AccountCode = line.Account?.AccountCode;
                line.AccountName = line.Account?.AccountName;
                line.DepartmentCode = line.Department?.DepartmentCode;
                line.DepartmentName = line.Department?.DepartmentName;
            }

            return lines;
        }
    }
}
