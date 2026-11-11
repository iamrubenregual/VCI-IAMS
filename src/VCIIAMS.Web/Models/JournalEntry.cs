using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace VCIIAMS.Web.Models
{
    [Table("JournalEntries")]
    public class JournalEntry
    {
        [Key]
        public int JournalEntryId { get; set; }

        [Required]
        [StringLength(30)]
        [Display(Name = "Journal #")]
        public string JournalNumber { get; set; } = string.Empty;

        [Required]
        [Display(Name = "Fiscal Period")]
        public int FiscalPeriodId { get; set; }

        [Required]
        [DataType(DataType.Date)]
        [Display(Name = "Entry Date")]
        public DateTime EntryDate { get; set; } = DateTime.Today;

        [DataType(DataType.Date)]
        [Display(Name = "Posting Date")]
        public DateTime? PostingDate { get; set; }

        [Required]
        [Display(Name = "Entry Type")]
        public int JournalEntryTypeId { get; set; }

        [Required]
        [StringLength(30)]
        [Display(Name = "Source Module")]
        public string SourceModule { get; set; } = "GL";

        [StringLength(100)]
        [Display(Name = "Source Reference")]
        public string? SourceReference { get; set; }

        [Required]
        [StringLength(500)]
        [Display(Name = "Description / Memo")]
        public string Description { get; set; } = string.Empty;

        [Required]
        [StringLength(20)]
        [Display(Name = "Status")]
        public string Status { get; set; } = "DRAFT"; // DRAFT, SUBMITTED, POSTED, REVERSED, VOID

        [Column(TypeName = "decimal(18,2)")]
        [Display(Name = "Total Debit")]
        public decimal TotalDebit { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        [Display(Name = "Total Credit")]
        public decimal TotalCredit { get; set; }

        [StringLength(100)]
        [Display(Name = "Posted By")]
        public string? PostedBy { get; set; }

        [Display(Name = "Posted Date")]
        public DateTime? PostedDate { get; set; }

        [Display(Name = "Reversal Of Entry")]
        public int? ReversalOfJournalEntryId { get; set; }

        [Required]
        [StringLength(100)]
        public string CreatedBy { get; set; } = string.Empty;

        public DateTime CreatedDate { get; set; } = DateTime.Now;

        [StringLength(100)]
        public string? ModifiedBy { get; set; }

        public DateTime? ModifiedDate { get; set; }

        // Navigation
        [ForeignKey("FiscalPeriodId")]
        public virtual FiscalPeriod? FiscalPeriod { get; set; }

        [ForeignKey("JournalEntryTypeId")]
        public virtual JournalEntryType? JournalEntryType { get; set; }

        [ForeignKey("ReversalOfJournalEntryId")]
        public virtual JournalEntry? ReversalOfJournalEntry { get; set; }

        public virtual ICollection<JournalEntryLine> Lines { get; set; } = new List<JournalEntryLine>();

        // Display properties (Not Mapped)
        [NotMapped]
        public bool IsBalanced => TotalDebit == TotalCredit && TotalDebit > 0;

        [NotMapped]
        public string? PeriodCode { get; set; }

        [NotMapped]
        public string? PeriodName { get; set; }

        [NotMapped]
        public string? FiscalYearCode { get; set; }

        [NotMapped]
        public string? EntryTypeCode { get; set; }

        [NotMapped]
        public string? EntryTypeName { get; set; }

        [NotMapped]
        public string? ReversalOfJournalNumber { get; set; }

        [NotMapped]
        public int LineCount => Lines?.Count ?? 0;
    }
}

