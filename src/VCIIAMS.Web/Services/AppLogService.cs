using VCIIAMS.Web.Models;

namespace VCIIAMS.Web.Services
{
    public class AppLogService : IAppLogService
    {
        public void LogAppEvent(AppLog log)
        {
            // Implement the logic to log the application event here
            Console.WriteLine($"Timestamp: {log.Timestamp}, Message: {log.Message}, ActionName: {log.ActionName}");
        }
    }
}