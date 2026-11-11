using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace VCIIAMS.Web.Models
{
    [Table("JournalEntryLines")]
    public class JournalEntryLine
    {
        [Key]
        public long JournalEntryLineId { get; set; }

        [Required]
        public int JournalEntryId { get; set; }

        [Required]
        [Display(Name = "Line #")]
        public int LineNumber { get; set; }

        [Required]
        [Display(Name = "Account")]
        public int AccountId { get; set; }

        [Display(Name = "Department")]
        public int? DepartmentId { get; set; }

        [Required]
        [Column(TypeName = "decimal(18,2)")]
        [Display(Name = "Debit")]
        public decimal DebitAmount { get; set; }

        [Required]
        [Column(TypeName = "decimal(18,2)")]
        [Display(Name = "Credit")]
        public decimal CreditAmount { get; set; }

        [StringLength(500)]
        [Display(Name = "Description")]
        public string? Description { get; set; }

        [StringLength(50)]
        [Display(Name = "Reference #")]
        public string? ReferenceNumber { get; set; }

        [Required]
        [StringLength(100)]
        public string CreatedBy { get; set; } = string.Empty;

        public DateTime CreatedDate { get; set; } = DateTime.Now;

        [StringLength(100)]
        public string? ModifiedBy { get; set; }

        public DateTime? ModifiedDate { get; set; }

        // Navigation
        [ForeignKey("JournalEntryId")]
        public virtual JournalEntry? JournalEntry { get; set; }

        [ForeignKey("AccountId")]
        public virtual ChartOfAccount? Account { get; set; }

        [ForeignKey("DepartmentId")]
        public virtual Department? Department { get; set; }

        // Display properties (Not Mapped)
        [NotMapped]
        public string? AccountCode { get; set; }

        [NotMapped]
        public string? AccountName { get; set; }

        [NotMapped]
        public string? DepartmentCode { get; set; }

        [NotMapped]
        public string? DepartmentName { get; set; }
    }
}

