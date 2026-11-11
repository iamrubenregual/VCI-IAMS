using System.Diagnostics;
using VCIIAMS.Web.Helpers;
using VCIIAMS.Web.Models;

namespace VCIIAMS.Web.Services
{
    public class AppLogService : IAppLogService
    {
        private readonly ILogger<AppLogService> _logger;

        public AppLogService(ILogger<AppLogService> logger)
        {
            _logger = logger;
        }

        public void LogAppEvent(AppLog log)
        {
            var logMessage = $"{DateTime.Now:yyyy-MM-dd HH:mm:ss} - {SessionHelper.GetUsername()}: {log.Message}, ActionName: {log.ActionName}";

            _logger.LogInformation("{LogMessage}", logMessage);
            Debug.WriteLine(logMessage);
            Console.WriteLine(logMessage);
        }
    }
}
