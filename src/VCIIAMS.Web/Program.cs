using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using VCIIAMS.Web.Data;
using VCIIAMS.Web.Models;
using VCIIAMS.Web.Services;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllersWithViews();
builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.LoginPath = "/Account/Login";
        options.ExpireTimeSpan = TimeSpan.FromMinutes(30);
        options.SlidingExpiration = true;
    });
builder.Services.AddScoped<IPasswordHasher<AuthenticationUser>, PasswordHasher<AuthenticationUser>>();

// Configure Database (MySQL 8.0+)
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseMySql(
        connectionString,
        new MySqlServerVersion(new Version(8, 0, 36))
    ));

// Register Services
builder.Services.AddScoped<IChartOfAccountService, ChartOfAccountService>();
builder.Services.AddScoped<IFiscalPeriodService, FiscalPeriodService>();
builder.Services.AddScoped<IAppLogService, AppLogService>();
builder.Services.AddScoped<IJournalEntryService, JournalEntryService>();

// Add Session
builder.Services.AddSession(options =>
{
    options.IdleTimeout = TimeSpan.FromMinutes(30);
    options.Cookie.HttpOnly = true;
    options.Cookie.IsEssential = true;
});

// Add logging
builder.Services.AddLogging(logging =>
{
    logging.AddConsole();
    logging.AddDebug();
});

var app = builder.Build();

if (args.Length > 0 && args[0] == "--reset-password")
{
    Environment.ExitCode = await PasswordResetCommand.RunAsync(app.Services, args);
    return;
}

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseRouting();

app.UseSession();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllerRoute(
    name: "login",
    pattern: "",
    defaults: new { controller = "Account", action = "Login" });

app.MapControllerRoute(
    name: "default",
    pattern: "{controller}/{action=Index}/{id?}");

app.Run();
