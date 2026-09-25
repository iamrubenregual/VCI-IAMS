using VCIIAMS.Web.Models;

namespace VCIIAMS.Web.Services
{
    public interface IAppLogService
    {
        void LogAppEvent(AppLog notification);
    }
}