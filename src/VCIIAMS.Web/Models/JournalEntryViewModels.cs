using System.ComponentModel.DataAnnotations;

namespace VCIIAMS.Web.Models
{
    public class JournalEntryLineInputModel
    {
        public long JournalEntryLineId { get; set; }

        public int LineNumber { get; set; }

        [Required(ErrorMessage = "Account is required")]
        [Display(Name = "Account")]
        public int AccountId { get; set; }

        [Display(Name = "Department")]
        public int? DepartmentId { get; set; }

        [Range(0, 999999999999.99, ErrorMessage = "Debit amount must be positive")]
        [Display(Name = "Debit")]
        public decimal? DebitAmount { get; set; }

        [Range(0, 999999999999.99, ErrorMessage = "Credit amount must be positive")]
        [Display(Name = "Credit")]
        public decimal? CreditAmount { get; set; }

        [StringLength(500)]
        [Display(Name = "Description")]
        public string? Description { get; set; }

        [StringLength(50)]
        [Display(Name = "Ref #")]
        public string? ReferenceNumber { get; set; }
    }

    public class JournalEntryCreateViewModel
    {
        public int JournalEntryId { get; set; }

        [Display(Name = "Journal Number")]
        public string? JournalNumber { get; set; }

        [Required(ErrorMessage = "Fiscal Period is required")]
        [Display(Name = "Fiscal Period")]
        public int FiscalPeriodId { get; set; }

        [Required(ErrorMessage = "Entry Date is required")]
        [DataType(DataType.Date)]
        [Display(Name = "Entry Date")]
        public DateTime EntryDate { get; set; } = DateTime.Today;

        [Required(ErrorMessage = "Entry Type is required")]
        [Display(Name = "Entry Type")]
        public int JournalEntryTypeId { get; set; }

        [Required]
        [StringLength(30)]
        [Display(Name = "Source Module")]
        public string SourceModule { get; set; } = "GL";

        [StringLength(100)]
        [Display(Name = "Source Reference")]
        public string? SourceReference { get; set; }

        [Required(ErrorMessage = "Description / Memo is required")]
        [StringLength(500)]
        [Display(Name = "Description / Memo")]
        public string Description { get; set; } = string.Empty;

        public List<JournalEntryLineInputModel> Lines { get; set; } = new List<JournalEntryLineInputModel>();
    }

    public class JournalEntryFilterViewModel
    {
        public int? FiscalPeriodId { get; set; }
        public string? Status { get; set; }
        public int? JournalEntryTypeId { get; set; }
        public DateTime? FromDate { get; set; }
        public DateTime? ToDate { get; set; }
        public string? SearchTerm { get; set; }
    }

    public class JournalEntryReverseViewModel
    {
        [Required]
        public int OriginalJournalEntryId { get; set; }

        public string JournalNumber { get; set; } = string.Empty;

        [Required(ErrorMessage = "Reversal Period is required")]
        [Display(Name = "Reversal Fiscal Period")]
        public int ReversalPeriodId { get; set; }

        [Required(ErrorMessage = "Reversal Date is required")]
        [DataType(DataType.Date)]
        [Display(Name = "Reversal Date")]
        public DateTime ReversalDate { get; set; } = DateTime.Today;

        [StringLength(500)]
        public string? Reason { get; set; }
    }
}

