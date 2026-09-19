using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using VCIIAMS.Web.Models;
using VCIIAMS.Web.Services;

namespace VCIIAMS.Web.Controllers
{
    public class ChartOfAccountsController : Controller
    {
        private readonly IChartOfAccountService _accountService;
        private readonly ILogger<ChartOfAccountsController> _logger;

        public ChartOfAccountsController(
            IChartOfAccountService accountService,
            ILogger<ChartOfAccountsController> logger)
        {
            _accountService = accountService;
            _logger = logger;
        }

        // GET: ChartOfAccounts
        public async Task<IActionResult> Index(bool includeInactive = false, int? accountTypeId = null)
        {
            try
            {
                var accounts = await _accountService.GetAllAccountsAsync(includeInactive, accountTypeId);
                ViewBag.IncludeInactive = includeInactive;
                ViewBag.AccountTypeId = accountTypeId;

                // Get account types for filter
                var accountTypes = await _accountService.GetAllAccountTypesAsync();
                ViewBag.AccountTypes = new SelectList(accountTypes, "AccountTypeId", "TypeName");

                return View(accounts);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error loading chart of accounts");
                TempData["Error"] = "Error loading accounts: " + ex.Message;
                return View(new List<ChartOfAccount>());
            }
        }

        // GET: ChartOfAccounts/Details/5
        public async Task<IActionResult> Details(int id)
        {
            try
            {
                var account = await _accountService.GetAccountByIdAsync(id);
                if (account == null)
                {
                    TempData["Error"] = "Account not found.";
                    return RedirectToAction(nameof(Index));
                }

                // Get child accounts
                var childAccounts = await _accountService.GetChildAccountsAsync(id);
                ViewBag.ChildAccounts = childAccounts;

                return View(account);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error loading account details for ID {AccountId}", id);
                TempData["Error"] = "Error loading account details: " + ex.Message;
                return RedirectToAction(nameof(Index));
            }
        }

        // GET: ChartOfAccounts/Create
        public async Task<IActionResult> Create()
        {
            await PopulateDropdowns();
            return View();
        }

        // POST: ChartOfAccounts/Create
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create(ChartOfAccount account)
        {
            try
            {
                if (ModelState.IsValid)
                {
                    // Check if account code already exists
                    if (await _accountService.AccountCodeExistsAsync(account.AccountCode))
                    {
                        ModelState.AddModelError("AccountCode", "Account code already exists.");
                        await PopulateDropdowns(account.AccountTypeId, account.ParentAccountId);
                        return View(account);
                    }

                    var currentUser = "admin";

                    var newId = await _accountService.CreateAccountAsync(account, currentUser);

                    TempData["Success"] = $"Account '{account.AccountName}' created successfully.";
                    return RedirectToAction(nameof(Details), new { id = newId });
                }

                await PopulateDropdowns(account.AccountTypeId, account.ParentAccountId);
                return View(account);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error creating account");
                ModelState.AddModelError("", "Error creating account: " + ex.Message);
                await PopulateDropdowns(account.AccountTypeId, account.ParentAccountId);
                return View(account);
            }
        }

        // GET: ChartOfAccounts/Edit/5
        public async Task<IActionResult> Edit(int id)
        {
            try
            {
                var account = await _accountService.GetAccountByIdAsync(id);
                if (account == null)
                {
                    TempData["Error"] = "Account not found.";
                    return RedirectToAction(nameof(Index));
                }

                await PopulateDropdowns(account.AccountTypeId, account.ParentAccountId);
                return View(account);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error loading account for edit");
                TempData["Error"] = "Error loading account: " + ex.Message;
                return RedirectToAction(nameof(Index));
            }
        }

        // POST: ChartOfAccounts/Edit/5
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Edit(int id, ChartOfAccount account)
        {
            if (id != account.AccountId)
            {
                return NotFound();
            }

            try
            {
                if (ModelState.IsValid)
                {
                    // Check if account code already exists for another account
                    if (await _accountService.AccountCodeExistsAsync(account.AccountCode, account.AccountId))
                    {
                        ModelState.AddModelError("AccountCode", "Account code already exists for another account.");
                        await PopulateDropdowns(account.AccountTypeId, account.ParentAccountId);
                        return View(account);
                    }

                    var currentUser = "admin";

                    var result = await _accountService.UpdateAccountAsync(account, currentUser);

                    if (result)
                    {
                        TempData["Success"] = $"Account '{account.AccountName}' updated successfully.";
                        return RedirectToAction(nameof(Details), new { id = account.AccountId });
                    }
                    else
                    {
                        ModelState.AddModelError("", "Error updating account.");
                    }
                }

                await PopulateDropdowns(account.AccountTypeId, account.ParentAccountId);
                return View(account);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error updating account");
                ModelState.AddModelError("", "Error updating account: " + ex.Message);
                await PopulateDropdowns(account.AccountTypeId, account.ParentAccountId);
                return View(account);
            }
        }

        // GET: ChartOfAccounts/Delete/5
        public async Task<IActionResult> Delete(int id)
        {
            try
            {
                var account = await _accountService.GetAccountByIdAsync(id);
                if (account == null)
                {
                    TempData["Error"] = "Account not found.";
                    return RedirectToAction(nameof(Index));
                }

                return View(account);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error loading account for delete");
                TempData["Error"] = "Error loading account: " + ex.Message;
                return RedirectToAction(nameof(Index));
            }
        }

        // POST: ChartOfAccounts/Delete/5
        [HttpPost, ActionName("Delete")]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> DeleteConfirmed(int id)
        {
            try
            {
                var currentUser = "admin";

                var result = await _accountService.DeleteAccountAsync(id, currentUser);

                if (result)
                {
                    TempData["Success"] = "Account deleted successfully.";
                }
                else
                {
                    TempData["Error"] = "Error deleting account. It may have child accounts or transactions.";
                }

                return RedirectToAction(nameof(Index));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error deleting account");
                TempData["Error"] = "Error deleting account: " + ex.Message;
                return RedirectToAction(nameof(Index));
            }
        }

        private async Task PopulateDropdowns(int? selectedAccountTypeId = null, int? selectedParentAccountId = null)
        {
            var accountTypes = await _accountService.GetAllAccountTypesAsync();
            ViewBag.AccountTypes = new SelectList(accountTypes, "AccountTypeId", "TypeName", selectedAccountTypeId);

            var headerAccounts = await _accountService.GetHeaderAccountsAsync();
            ViewBag.ParentAccounts = new SelectList(headerAccounts, "AccountId", "AccountName", selectedParentAccountId);
        }
    }
}
