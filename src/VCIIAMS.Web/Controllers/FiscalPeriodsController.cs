using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using VCIIAMS.Web.Models;
using VCIIAMS.Web.Services;

namespace VCIIAMS.Web.Controllers
{
    public class FiscalPeriodsController : Controller
    {
        private readonly IFiscalPeriodService _fiscalPeriodService;
        private readonly ILogger<FiscalPeriodsController> _logger;

        public FiscalPeriodsController(
            IFiscalPeriodService fiscalPeriodService,
            ILogger<FiscalPeriodsController> logger)
        {
            _fiscalPeriodService = fiscalPeriodService;
            _logger = logger;
        }

        // GET: FiscalPeriods
        public async Task<IActionResult> Index(bool includeInactive = false)
        {
            try
            {
                var fiscalYears = await _fiscalPeriodService.GetAllFiscalYearsAsync(includeInactive);
                ViewBag.IncludeInactive = includeInactive;
                return View(fiscalYears);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error loading fiscal years");
                TempData["Error"] = "Error loading fiscal years: " + ex.Message;
                return View(new List<FiscalYear>());
            }
        }

        // GET: FiscalPeriods/Details/5
        public async Task<IActionResult> Details(int id)
        {
            try
            {
                var fiscalYear = await _fiscalPeriodService.GetFiscalYearByIdAsync(id);
                if (fiscalYear == null)
                {
                    TempData["Error"] = "Fiscal year not found.";
                    return RedirectToAction(nameof(Index));
                }

                // Get periods for this fiscal year
                var periods = await _fiscalPeriodService.GetPeriodsByYearAsync(id);
                ViewBag.FiscalPeriods = periods;

                return View(fiscalYear);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error loading fiscal year details");
                TempData["Error"] = "Error loading fiscal year details: " + ex.Message;
                return RedirectToAction(nameof(Index));
            }
        }

        // GET: FiscalPeriods/CreateYear
        public IActionResult CreateYear()
        {
            return View();
        }

        // POST: FiscalPeriods/CreateYear
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> CreateYear(FiscalYear fiscalYear, bool createPeriods = true)
        {
            try
            {
                // Remove properties not submitted in the form from validation
                ModelState.Remove("CreatedBy");

                if (ModelState.IsValid)
                {
                    // Validate dates
                    if (fiscalYear.EndDate <= fiscalYear.StartDate)
                    {
                        ModelState.AddModelError("EndDate", "End date must be after start date.");
                        return View(fiscalYear);
                    }

                    // Check if fiscal year code already exists
                    if (await _fiscalPeriodService.FiscalYearCodeExistsAsync(fiscalYear.FiscalYearCode))
                    {
                        ModelState.AddModelError("FiscalYearCode", "Fiscal year code already exists.");
                        return View(fiscalYear);
                    }

                    // TODO: Get current user from authentication
                    var currentUser = "admin"; // Temporary hardcoded user

                    var newId = await _fiscalPeriodService.CreateFiscalYearAsync(fiscalYear, createPeriods, currentUser);

                    TempData["Success"] = $"Fiscal year '{fiscalYear.FiscalYearName}' created successfully.";
                    return RedirectToAction(nameof(Details), new { id = newId });
                }

                return View(fiscalYear);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error creating fiscal year");
                ModelState.AddModelError("", "Error creating fiscal year: " + ex.Message);
                return View(fiscalYear);
            }
        }

        // GET: FiscalPeriods/EditYear/5
        public async Task<IActionResult> EditYear(int id)
        {
            try
            {
                var fiscalYear = await _fiscalPeriodService.GetFiscalYearByIdAsync(id);
                if (fiscalYear == null)
                {
                    TempData["Error"] = "Fiscal year not found.";
                    return RedirectToAction(nameof(Index));
                }

                if (fiscalYear.IsClosed)
                {
                    TempData["Error"] = "Cannot edit a closed fiscal year.";
                    return RedirectToAction(nameof(Details), new { id });
                }

                return View(fiscalYear);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error loading fiscal year for edit");
                TempData["Error"] = "Error loading fiscal year: " + ex.Message;
                return RedirectToAction(nameof(Index));
            }
        }

        // POST: FiscalPeriods/EditYear/5
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> EditYear(int id, FiscalYear fiscalYear)
        {
            if (id != fiscalYear.FiscalYearId)
            {
                return NotFound();
            }

            try
            {
                // Remove properties not submitted in the form from validation
                ModelState.Remove("CreatedBy");

                if (ModelState.IsValid)
                {
                    // Validate dates
                    if (fiscalYear.EndDate <= fiscalYear.StartDate)
                    {
                        ModelState.AddModelError("EndDate", "End date must be after start date.");
                        return View(fiscalYear);
                    }

                    // Check if fiscal year code already exists for another fiscal year
                    if (await _fiscalPeriodService.FiscalYearCodeExistsAsync(fiscalYear.FiscalYearCode, fiscalYear.FiscalYearId))
                    {
                        ModelState.AddModelError("FiscalYearCode", "Fiscal year code already exists for another fiscal year.");
                        return View(fiscalYear);
                    }

                    // TODO: Get current user from authentication
                    var currentUser = "admin"; // Temporary hardcoded user

                    var result = await _fiscalPeriodService.UpdateFiscalYearAsync(fiscalYear, currentUser);

                    if (result)
                    {
                        TempData["Success"] = $"Fiscal year '{fiscalYear.FiscalYearName}' updated successfully.";
                        return RedirectToAction(nameof(Details), new { id = fiscalYear.FiscalYearId });
                    }
                    else
                    {
                        ModelState.AddModelError("", "Error updating fiscal year.");
                    }
                }

                return View(fiscalYear);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error updating fiscal year");
                ModelState.AddModelError("", "Error updating fiscal year: " + ex.Message);
                return View(fiscalYear);
            }
        }

        // POST: FiscalPeriods/CloseYear/5
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> CloseYear(int id)
        {
            try
            {
                // TODO: Get current user from authentication
                var currentUser = "admin"; // Temporary hardcoded user

                var result = await _fiscalPeriodService.CloseFiscalYearAsync(id, currentUser);

                if (result)
                {
                    TempData["Success"] = "Fiscal year closed successfully.";
                }
                else
                {
                    TempData["Error"] = "Error closing fiscal year.";
                }

                return RedirectToAction(nameof(Details), new { id });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error closing fiscal year");
                TempData["Error"] = "Error closing fiscal year: " + ex.Message;
                return RedirectToAction(nameof(Details), new { id });
            }
        }

        // POST: FiscalPeriods/ClosePeriod/5
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> ClosePeriod(int id, int fiscalYearId)
        {
            try
            {
                // TODO: Get current user from authentication
                var currentUser = "admin"; // Temporary hardcoded user

                var result = await _fiscalPeriodService.CloseFiscalPeriodAsync(id, currentUser);

                if (result)
                {
                    TempData["Success"] = "Fiscal period closed successfully.";
                }
                else
                {
                    TempData["Error"] = "Error closing fiscal period.";
                }

                return RedirectToAction(nameof(Details), new { id = fiscalYearId });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error closing fiscal period");
                TempData["Error"] = "Error closing fiscal period: " + ex.Message;
                return RedirectToAction(nameof(Details), new { id = fiscalYearId });
            }
        }

        // GET: FiscalPeriods/Periods
        public async Task<IActionResult> Periods(int? fiscalYearId, bool includeInactive = false)
        {
            try
            {
                var periods = await _fiscalPeriodService.GetAllFiscalPeriodsAsync(fiscalYearId, includeInactive);
                var fiscalYears = await _fiscalPeriodService.GetAllFiscalYearsAsync();

                ViewBag.FiscalYears = new SelectList(fiscalYears, "FiscalYearId", "FiscalYearName", fiscalYearId);
                ViewBag.IncludeInactive = includeInactive;
                ViewBag.SelectedFiscalYearId = fiscalYearId;

                return View(periods);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error loading fiscal periods");
                TempData["Error"] = "Error loading fiscal periods: " + ex.Message;
                return View(new List<FiscalPeriod>());
            }
        }
    }
}
