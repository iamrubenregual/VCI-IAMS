using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using VCIIAMS.Web.Models;
using VCIIAMS.Web.Services;

namespace VCIIAMS.Web.Controllers
{
    public class JournalEntriesController : Controller
    {
        private readonly IJournalEntryService _journalService;
        private readonly IChartOfAccountService _accountService;
        private readonly IFiscalPeriodService _fiscalPeriodService;
        private readonly ILogger<JournalEntriesController> _logger;

        public JournalEntriesController(
            IJournalEntryService journalService,
            IChartOfAccountService accountService,
            IFiscalPeriodService fiscalPeriodService,
            ILogger<JournalEntriesController> logger)
        {
            _journalService = journalService;
            _accountService = accountService;
            _fiscalPeriodService = fiscalPeriodService;
            _logger = logger;
        }

        // GET: /JournalEntries
        public async Task<IActionResult> Index(JournalEntryFilterViewModel filter)
        {
            try
            {
                var entries = await _journalService.GetJournalEntriesAsync(
                    filter.FiscalPeriodId,
                    filter.Status,
                    filter.JournalEntryTypeId,
                    filter.FromDate,
                    filter.ToDate,
                    filter.SearchTerm);

                var entriesList = entries.ToList();

                // Compute summary metrics
                ViewBag.TotalCount = entriesList.Count;
                ViewBag.DraftCount = entriesList.Count(e => e.Status == "DRAFT");
                ViewBag.PostedCount = entriesList.Count(e => e.Status == "POSTED");
                ViewBag.TotalPostedDebit = entriesList.Where(e => e.Status == "POSTED").Sum(e => e.TotalDebit);

                // Populate filter dropdowns
                await LoadDropdownsAsync(filter.FiscalPeriodId, filter.JournalEntryTypeId);

                ViewBag.Filter = filter;
                return View(entriesList);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error loading journal entries list");
                TempData["Error"] = "Failed to load journal entries: " + ex.Message;
                return View(new List<JournalEntry>());
            }
        }

        // GET: /JournalEntries/Details/5
        public async Task<IActionResult> Details(int id)
        {
            try
            {
                var entry = await _journalService.GetJournalEntryByIdAsync(id);
                if (entry == null)
                {
                    TempData["Error"] = "Journal entry not found.";
                    return RedirectToAction(nameof(Index));
                }

                // If posted, load open fiscal periods for possible reversal modal
                if (entry.Status == "POSTED")
                {
                    var openPeriods = await _journalService.GetOpenFiscalPeriodsAsync();
                    ViewBag.OpenPeriods = new SelectList(openPeriods, "FiscalPeriodId", "PeriodCode", entry.FiscalPeriodId);
                }

                return View(entry);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error loading journal entry details {Id}", id);
                TempData["Error"] = "Error loading journal entry: " + ex.Message;
                return RedirectToAction(nameof(Index));
            }
        }

        // GET: /JournalEntries/Create
        public async Task<IActionResult> Create()
        {
            try
            {
                var nextNumber = await _journalService.GenerateNextJournalNumberAsync();
                var openPeriods = await _journalService.GetOpenFiscalPeriodsAsync();
                var currentPeriod = await _fiscalPeriodService.GetCurrentFiscalPeriodAsync();

                var model = new JournalEntryCreateViewModel
                {
                    JournalNumber = nextNumber,
                    EntryDate = DateTime.Today,
                    FiscalPeriodId = currentPeriod?.FiscalPeriodId ?? openPeriods.FirstOrDefault()?.FiscalPeriodId ?? 0,
                    Lines = new List<JournalEntryLineInputModel>
                    {
                        new JournalEntryLineInputModel { LineNumber = 1 },
                        new JournalEntryLineInputModel { LineNumber = 2 }
                    }
                };

                await LoadFormDropdownsAsync();
                return View(model);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error opening journal entry create form");
                TempData["Error"] = "Error opening form: " + ex.Message;
                return RedirectToAction(nameof(Index));
            }
        }

        // POST: /JournalEntries/Create
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create(JournalEntryCreateViewModel model, string? submitAction)
        {
            try
            {
                // Filter out blank lines
                var validLines = model.Lines
                    .Where(l => l.AccountId > 0 && ((l.DebitAmount ?? 0) > 0 || (l.CreditAmount ?? 0) > 0))
                    .ToList();

                if (validLines.Count < 2)
                {
                    ModelState.AddModelError("", "A journal entry must contain at least two non-zero lines (at least one debit and one credit).");
                }

                var totalDebit = validLines.Sum(l => l.DebitAmount ?? 0);
                var totalCredit = validLines.Sum(l => l.CreditAmount ?? 0);

                if (totalDebit != totalCredit)
                {
                    ModelState.AddModelError("", $"Total debits ({totalDebit:N2}) must equal total credits ({totalCredit:N2}). Current difference: {Math.Abs(totalDebit - totalCredit):N2}.");
                }

                if (!ModelState.IsValid)
                {
                    await LoadFormDropdownsAsync();
                    model.Lines = validLines.Any() ? validLines : model.Lines;
                    return View(model);
                }

                var username = User?.Identity?.Name ?? "admin";
                var entry = new JournalEntry
                {
                    JournalNumber = model.JournalNumber ?? await _journalService.GenerateNextJournalNumberAsync(),
                    FiscalPeriodId = model.FiscalPeriodId,
                    EntryDate = model.EntryDate,
                    JournalEntryTypeId = model.JournalEntryTypeId,
                    SourceModule = model.SourceModule ?? "GL",
                    SourceReference = model.SourceReference,
                    Description = model.Description,
                    Status = "DRAFT",
                    TotalDebit = totalDebit,
                    TotalCredit = totalCredit,
                    Lines = validLines.Select((l, idx) => new JournalEntryLine
                    {
                        LineNumber = idx + 1,
                        AccountId = l.AccountId,
                        DepartmentId = l.DepartmentId > 0 ? l.DepartmentId : null,
                        DebitAmount = l.DebitAmount ?? 0,
                        CreditAmount = l.CreditAmount ?? 0,
                        Description = l.Description,
                        ReferenceNumber = l.ReferenceNumber
                    }).ToList()
                };

                var entryId = await _journalService.CreateJournalEntryAsync(entry, username);

                if (submitAction == "SaveAndPost")
                {
                    var postResult = await _journalService.PostJournalEntryAsync(entryId, username);
                    if (postResult.Success)
                    {
                        TempData["Success"] = $"Journal Entry {entry.JournalNumber} was created and posted successfully!";
                        return RedirectToAction(nameof(Details), new { id = entryId });
                    }
                    else
                    {
                        TempData["Warning"] = $"Journal Entry {entry.JournalNumber} was saved as Draft, but posting failed: {postResult.Message}";
                        return RedirectToAction(nameof(Details), new { id = entryId });
                    }
                }

                TempData["Success"] = $"Draft Journal Entry {entry.JournalNumber} saved successfully!";
                return RedirectToAction(nameof(Details), new { id = entryId });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error creating journal entry");
                ModelState.AddModelError("", "An unexpected error occurred: " + ex.Message);
                await LoadFormDropdownsAsync();
                return View(model);
            }
        }

        // POST: /JournalEntries/Post/5
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Post(int id)
        {
            try
            {
                var username = User?.Identity?.Name ?? "admin";
                var result = await _journalService.PostJournalEntryAsync(id, username);

                if (result.Success)
                    TempData["Success"] = result.Message;
                else
                    TempData["Error"] = result.Message;

                return RedirectToAction(nameof(Details), new { id });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error posting journal entry {Id}", id);
                TempData["Error"] = "Error posting entry: " + ex.Message;
                return RedirectToAction(nameof(Details), new { id });
            }
        }

        // POST: /JournalEntries/Reverse
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Reverse(JournalEntryReverseViewModel model)
        {
            try
            {
                var username = User?.Identity?.Name ?? "admin";
                var result = await _journalService.ReverseJournalEntryAsync(
                    model.OriginalJournalEntryId,
                    model.ReversalPeriodId,
                    model.ReversalDate,
                    username);

                if (result.Success)
                {
                    TempData["Success"] = result.Message;
                    if (result.NewEntryId.HasValue)
                        return RedirectToAction(nameof(Details), new { id = result.NewEntryId.Value });
                }
                else
                {
                    TempData["Error"] = result.Message;
                }

                return RedirectToAction(nameof(Details), new { id = model.OriginalJournalEntryId });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error reversing journal entry {Id}", model.OriginalJournalEntryId);
                TempData["Error"] = "Error reversing entry: " + ex.Message;
                return RedirectToAction(nameof(Details), new { id = model.OriginalJournalEntryId });
            }
        }

        // POST: /JournalEntries/Void/5
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Void(int id)
        {
            try
            {
                var username = User?.Identity?.Name ?? "admin";
                var result = await _journalService.VoidJournalEntryAsync(id, username);

                if (result.Success)
                    TempData["Success"] = result.Message;
                else
                    TempData["Error"] = result.Message;

                return RedirectToAction(nameof(Details), new { id });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error voiding journal entry {Id}", id);
                TempData["Error"] = "Error voiding entry: " + ex.Message;
                return RedirectToAction(nameof(Details), new { id });
            }
        }

        // POST: /JournalEntries/Delete/5
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Delete(int id)
        {
            try
            {
                var success = await _journalService.DeleteDraftJournalEntryAsync(id);
                if (success)
                    TempData["Success"] = "Draft journal entry deleted successfully.";
                else
                    TempData["Error"] = "Unable to delete journal entry. Only DRAFT entries can be deleted.";

                return RedirectToAction(nameof(Index));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error deleting journal entry {Id}", id);
                TempData["Error"] = "Error deleting entry: " + ex.Message;
                return RedirectToAction(nameof(Index));
            }
        }

        // GET: /JournalEntries/GeneralLedger
        public async Task<IActionResult> GeneralLedger(int? accountId, int? fiscalPeriodId, DateTime? fromDate, DateTime? toDate)
        {
            try
            {
                var lines = await _journalService.GetGeneralLedgerLinesAsync(accountId, fiscalPeriodId, fromDate, toDate);

                // Populate filters
                var accounts = await _accountService.GetAllAccountsAsync(includeInactive: false);
                var detailAccounts = accounts.Where(a => !a.IsHeader).OrderBy(a => a.AccountCode);
                ViewBag.Accounts = new SelectList(detailAccounts, "AccountId", "AccountCode", accountId);

                var periods = await _fiscalPeriodService.GetAllFiscalPeriodsAsync();
                ViewBag.FiscalPeriods = new SelectList(periods, "FiscalPeriodId", "PeriodCode", fiscalPeriodId);

                ViewBag.SelectedAccountId = accountId;
                ViewBag.SelectedFiscalPeriodId = fiscalPeriodId;
                ViewBag.FromDate = fromDate?.ToString("yyyy-MM-dd");
                ViewBag.ToDate = toDate?.ToString("yyyy-MM-dd");

                return View(lines);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error loading General Ledger");
                TempData["Error"] = "Error loading General Ledger: " + ex.Message;
                return View(new List<JournalEntryLine>());
            }
        }

        private async Task LoadDropdownsAsync(int? selectedPeriodId = null, int? selectedTypeId = null)
        {
            var periods = await _fiscalPeriodService.GetAllFiscalPeriodsAsync();
            ViewBag.FiscalPeriods = new SelectList(periods, "FiscalPeriodId", "PeriodCode", selectedPeriodId);

            var types = await _journalService.GetJournalEntryTypesAsync();
            ViewBag.JournalEntryTypes = new SelectList(types, "JournalEntryTypeId", "TypeName", selectedTypeId);
        }

        private async Task LoadFormDropdownsAsync()
        {
            var openPeriods = await _journalService.GetOpenFiscalPeriodsAsync();
            ViewBag.FiscalPeriods = new SelectList(openPeriods, "FiscalPeriodId", "PeriodCode");

            var types = await _journalService.GetJournalEntryTypesAsync();
            ViewBag.JournalEntryTypes = new SelectList(types, "JournalEntryTypeId", "TypeName");

            var accounts = await _accountService.GetAllAccountsAsync(includeInactive: false);
            // Only allow manual entry on non-header accounts
            var postableAccounts = accounts
                .Where(a => !a.IsHeader && a.AllowManualEntry)
                .OrderBy(a => a.AccountCode)
                .Select(a => new
                {
                    a.AccountId,
                    DisplayText = $"{a.AccountCode} - {a.AccountName}"
                });
            ViewBag.Accounts = new SelectList(postableAccounts, "AccountId", "DisplayText");

            var departments = await _journalService.GetDepartmentsAsync();
            ViewBag.Departments = new SelectList(departments, "DepartmentId", "DepartmentName");
        }
    }
}
