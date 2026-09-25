using System.ComponentModel.DataAnnotations;

namespace VCIIAMS.Web.Models
{
    public class AppLog
    {
            public AppLog(DateTime timestamp, string message, string actionName)
            {
                Timestamp = timestamp;
                Message = message;
                ActionName = actionName;
            }

            [Required]
            public DateTime Timestamp { get; set; }

            [Required]
            public string Message { get; set; }

            [Required]
            public string ActionName { get; set; }
        
    }
}