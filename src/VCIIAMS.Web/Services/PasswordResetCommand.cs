using System.Text;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using VCIIAMS.Web.Data;
using VCIIAMS.Web.Models;

namespace VCIIAMS.Web.Services
{
    public static class PasswordResetCommand
    {
        public static async Task<int> RunAsync(IServiceProvider services, string[] args)
        {
            if (args.Length != 2 || string.IsNullOrWhiteSpace(args[1]) || Console.IsInputRedirected)
            {
                Console.Error.WriteLine("Usage: dotnet run -- --reset-password <username> (interactive terminal required)");
                return 1;
            }

            using var scope = services.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var user = await context.Users.SingleOrDefaultAsync(u => u.Username == args[1]);
            if (user == null)
            {
                Console.Error.WriteLine("User not found.");
                return 1;
            }

            var password = ReadPassword("New password: ");
            var confirmation = ReadPassword("Confirm password: ");
            if (password.Length < 12 || password != confirmation)
            {
                Console.Error.WriteLine("Passwords must match and contain at least 12 characters.");
                return 1;
            }

            var hasher = scope.ServiceProvider.GetRequiredService<IPasswordHasher<AuthenticationUser>>();
            user.PasswordHash = hasher.HashPassword(user, password);
            await context.SaveChangesAsync();
            Console.WriteLine("Password updated.");
            return 0;
        }

        private static string ReadPassword(string prompt)
        {
            Console.Write(prompt);
            var password = new StringBuilder();
            ConsoleKeyInfo key;
            while ((key = Console.ReadKey(intercept: true)).Key != ConsoleKey.Enter)
            {
                if (key.Key == ConsoleKey.Backspace && password.Length > 0)
                {
                    password.Length--;
                }
                else if (!char.IsControl(key.KeyChar))
                {
                    password.Append(key.KeyChar);
                }
            }
            Console.WriteLine();
            return password.ToString();
        }
    }
}
