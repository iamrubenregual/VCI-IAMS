using System.Security.Claims;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using VCIIAMS.Web.Data;
using VCIIAMS.Web.Models;

namespace VCIIAMS.Web.Controllers
{
    [ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
    public class AccountController : Controller
    {
        private readonly ApplicationDbContext _context;
        private readonly IPasswordHasher<AuthenticationUser> _passwordHasher;
        private readonly ILogger<AccountController> _logger;

        public AccountController(
            ApplicationDbContext context,
            IPasswordHasher<AuthenticationUser> passwordHasher,
            ILogger<AccountController> logger)
        {
            _context = context;
            _passwordHasher = passwordHasher;
            _logger = logger;
        }

        [HttpGet]
        public IActionResult Login()
        {
            return User.Identity?.IsAuthenticated == true
                ? RedirectToAction("Index", "Home")
                : View(new LoginViewModel());
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Login(LoginViewModel model)
        {
            if (!ModelState.IsValid)
            {
                return View(model);
            }

            var username = model.Username.Trim();
            var user = await _context.Users.AsNoTracking()
                .SingleOrDefaultAsync(u => u.Username == username);

            var passwordResult = PasswordVerificationResult.Failed;
            if (user != null && user.IsActive && !user.IsLocked)
            {
                try
                {
                    passwordResult = _passwordHasher.VerifyHashedPassword(user, user.PasswordHash, model.Password);
                }
                catch (FormatException)
                {
                    _logger.LogWarning("User {UserId} has an invalid password hash", user.UserId);
                }
            }

            if (user == null || passwordResult == PasswordVerificationResult.Failed)
            {
                ModelState.AddModelError(string.Empty, "Invalid username or password, or the account is unavailable.");
                return View(model);
            }

            var claims = new[]
            {
                new Claim(ClaimTypes.NameIdentifier, user.UserId.ToString()),
                new Claim(ClaimTypes.Name, user.Username)
            };
            var identity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);
            await HttpContext.SignInAsync(
                CookieAuthenticationDefaults.AuthenticationScheme,
                new ClaimsPrincipal(identity));

            return RedirectToAction("Index", "Home");
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Logout()
        {
            await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
            return RedirectToAction(nameof(Login));
        }
    }
}
