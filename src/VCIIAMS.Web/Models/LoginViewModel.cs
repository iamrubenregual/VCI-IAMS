using System.ComponentModel.DataAnnotations;

namespace VCIIAMS.Web.Models
{
    public class LoginViewModel
    {
        [Required]
        [StringLength(50)]
        public string Username { get; set; } = string.Empty;

        [Required]
        [DataType(DataType.Password)]
        [StringLength(1024)]
        public string Password { get; set; } = string.Empty;
    }
}
