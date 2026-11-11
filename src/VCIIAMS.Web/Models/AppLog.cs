using System.ComponentModel.DataAnnotations;

namespace VCIIAMS.Web.Models
{
    public class AppLog
    {
            public AppLog(string message, string actionName)
            {
                Message = message;
                ActionName = actionName;
            }

            [Required]
            public string Message { get; set; }

            [Required]
            public string ActionName { get; set; }
        
    }
}