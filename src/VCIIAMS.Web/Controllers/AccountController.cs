using System.Security.Claims;
using Dapper;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Identity;
using Microsoft.Data.SqlClient;
using VCIIAMS.Web.Models;

namespace VCIIAMS.Web.Controllers
{
    public class AccountController : Controller
    {
        private readonly IConfiguration _configuration;
        private readonly PasswordHasher<object> _passwordHasher = new();

        public AccountController(IConfiguration configuration)
        {
            _configuration = configuration;
        }

        [HttpGet]
        public IActionResult Login(string? returnUrl = null)
        {
            if (User.Identity?.IsAuthenticated == true)
            {
                return RedirectToLocal(returnUrl);
            }

            return View(new LoginViewModel { ReturnUrl = returnUrl });
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Login(LoginViewModel model)
        {
            if (!ModelState.IsValid)
            {
                return View(model);
            }

            await using var connection = new SqlConnection(_configuration.GetConnectionString("DefaultConnection"));
            var users = await connection.QueryAsync<UserLoginRecord>(
                """
                SELECT u.UserId, u.Username, u.PasswordHash, u.IsActive, u.IsLocked,
                       r.RoleName
                FROM Users u
                LEFT JOIN UserRoles ur ON ur.UserId = u.UserId
                LEFT JOIN Roles r ON r.RoleId = ur.RoleId AND r.IsActive = 1
                WHERE u.Username = @Username
                """,
                new { model.Username });

            var user = users.FirstOrDefault();

            if (user == null || !user.IsActive || user.IsLocked ||
                _passwordHasher.VerifyHashedPassword(new object(), user.PasswordHash, model.Password) == PasswordVerificationResult.Failed)
            {
                ModelState.AddModelError(string.Empty, "Invalid username or password.");
                return View(model);
            }

            var claims = new List<Claim>
            {
                new(ClaimTypes.NameIdentifier, user.UserId.ToString()),
                new(ClaimTypes.Name, user.Username)
            };

            foreach (var roleName in users
                .Select(record => record.RoleName)
                .Where(roleName => !string.IsNullOrWhiteSpace(roleName))
                .Distinct(StringComparer.OrdinalIgnoreCase))
            {
                claims.Add(new Claim(ClaimTypes.Role, roleName!));
            }

            await HttpContext.SignInAsync(
                CookieAuthenticationDefaults.AuthenticationScheme,
                new ClaimsPrincipal(new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme)));

            await connection.ExecuteAsync(
                "UPDATE Users SET LastLoginDate = GETDATE(), FailedLoginAttempts = 0 WHERE UserId = @UserId",
                new { user.UserId });

            return RedirectToLocal(model.ReturnUrl);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Logout()
        {
            await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
            return RedirectToAction(nameof(Login));
        }

        [HttpGet]
        public IActionResult AccessDenied()
        {
            return View();
        }

        private IActionResult RedirectToLocal(string? returnUrl)
        {
            return !string.IsNullOrWhiteSpace(returnUrl) && Url.IsLocalUrl(returnUrl)
                ? Redirect(returnUrl)
                : RedirectToAction("Index", "Home");
        }

        private sealed class UserLoginRecord
        {
            public int UserId { get; init; }
            public string Username { get; init; } = string.Empty;
            public string PasswordHash { get; init; } = string.Empty;
            public bool IsActive { get; init; }
            public bool IsLocked { get; init; }
            public string? RoleName { get; init; }
        }
    }
}