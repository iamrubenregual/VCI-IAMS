using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace VCIIAMS.Web.Models
{
    [Table("ChartOfAccounts")]
    public class ChartOfAccount
    {
        [Key]
        public int AccountId { get; set; }

        [Required]
        [StringLength(50)]
        [Display(Name = "Account Code")]
        public string AccountCode { get; set; } = string.Empty;

        [Required]
        [StringLength(200)]
        [Display(Name = "Account Name")]
        public string AccountName { get; set; } = string.Empty;

        [Required]
        [Display(Name = "Account Type")]
        public int AccountTypeId { get; set; }

        [Display(Name = "Parent Account")]
        public int? ParentAccountId { get; set; }

        [StringLength(500)]
        public string? Description { get; set; }

        [Display(Name = "Is Header")]
        public bool IsHeader { get; set; }

        [Display(Name = "Active")]
        public bool IsActive { get; set; } = true;

        [Display(Name = "Allow Manual Entry")]
        public bool AllowManualEntry { get; set; } = true;

        public int Level { get; set; } = 1;

        [Display(Name = "Department")]
        public int? DepartmentId { get; set; }

        [Display(Name = "Opening Balance")]
        [Column(TypeName = "decimal(18,2)")]
        public decimal OpeningBalance { get; set; }

        [Display(Name = "Opening Balance Date")]
        public DateTime? OpeningBalanceDate { get; set; }

        [Required]
        [StringLength(100)]
        public string CreatedBy { get; set; } = string.Empty;

        public DateTime CreatedDate { get; set; } = DateTime.Now;

        [StringLength(100)]
        public string? ModifiedBy { get; set; }

        public DateTime? ModifiedDate { get; set; }

        // Navigation properties
        [ForeignKey("AccountTypeId")]
        public virtual AccountType? AccountType { get; set; }

        [ForeignKey("ParentAccountId")]
        public virtual ChartOfAccount? ParentAccount { get; set; }

        public virtual ICollection<ChartOfAccount>? ChildAccounts { get; set; }

        // Additional properties for display
        [NotMapped]
        public string? ParentAccountName { get; set; }

        [NotMapped]
        public string? AccountTypeName { get; set; }

        [NotMapped]
        public string? HierarchyPath { get; set; }
    }
}
