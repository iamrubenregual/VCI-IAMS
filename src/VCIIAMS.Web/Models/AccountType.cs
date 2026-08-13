using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace VCIIAMS.Web.Models
{
    [Table("AccountTypes")]
    public class AccountType
    {
        [Key]
        public int AccountTypeId { get; set; }

        [Required]
        [StringLength(20)]
        public string TypeCode { get; set; } = string.Empty;

        [Required]
        [StringLength(50)]
        public string TypeName { get; set; } = string.Empty;

        [Required]
        [StringLength(10)]
        public string NormalBalance { get; set; } = string.Empty; // DEBIT or CREDIT

        [Required]
        [StringLength(50)]
        public string Category { get; set; } = string.Empty; // ASSET, LIABILITY, EQUITY, REVENUE, EXPENSE

        public int DisplayOrder { get; set; }

        public bool IsActive { get; set; } = true;

        [Required]
        [StringLength(100)]
        public string CreatedBy { get; set; } = string.Empty;

        public DateTime CreatedDate { get; set; } = DateTime.Now;

        [StringLength(100)]
        public string? ModifiedBy { get; set; }

        public DateTime? ModifiedDate { get; set; }

        // Navigation properties
        public virtual ICollection<ChartOfAccount>? ChartOfAccounts { get; set; }
    }
}
