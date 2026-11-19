namespace VCIIAMS.Web.Models
{
    public class AuthenticationUser
    {
        public int UserId { get; set; }
        public string Username { get; set; } = string.Empty;
        public string PasswordHash { get; set; } = string.Empty;
        public bool IsActive { get; set; }
        public bool IsLocked { get; set; }
    }
}
