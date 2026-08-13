using Microsoft.AspNetCore.Mvc;
using VCIIAMS.Web.Services;

namespace VCIIAMS.Web.Controllers
{
    public class HomeController : Controller
    {
        private readonly IChartOfAccountService _accountService;
        private readonly IFiscalPeriodService _fiscalPeriodService;
        private readonly ILogger<HomeController> _logger;

        public HomeController(
            IChartOfAccountService accountService,
            IFiscalPeriodService fiscalPeriodService,
            ILogger<HomeController> logger)
        {
            _accountService = accountService;
            _fiscalPeriodService = fiscalPeriodService;
            _logger = logger;
        }

        public async Task<IActionResult> Index()
        {
            try
            {
                // Get dashboard statistics
                var allAccounts = await _accountService.GetAllAccountsAsync(includeInactive: false);
                var allFiscalYears = await _fiscalPeriodService.GetAllFiscalYearsAsync(includeInactive: false);
                var currentPeriod = await _fiscalPeriodService.GetCurrentFiscalPeriodAsync();

                ViewBag.TotalAccounts = allAccounts.Count();
                ViewBag.ActiveAccounts = allAccounts.Count(a => a.IsActive);
                ViewBag.HeaderAccounts = allAccounts.Count(a => a.IsHeader);
                ViewBag.DetailAccounts = allAccounts.Count(a => !a.IsHeader);

                ViewBag.TotalFiscalYears = allFiscalYears.Count();
                ViewBag.OpenFiscalYears = allFiscalYears.Count(fy => !fy.IsClosed);
                ViewBag.CurrentPeriod = currentPeriod;

                // Account breakdown by type
                var accountsByType = allAccounts
                    .GroupBy(a => new { a.AccountTypeId, a.TypeName })
                    .Select(g => new { TypeName = g.Key.TypeName, Count = g.Count() })
                    .ToList();

                ViewBag.AccountsByType = accountsByType;

                return View();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error loading dashboard");
                TempData["Error"] = "Error loading dashboard: " + ex.Message;
                return View();
            }
        }

        public IActionResult Error()
        {
            return View();
        }
    }
}
