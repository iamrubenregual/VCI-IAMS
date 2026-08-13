using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace VCIIAMS.Web.Models
{
    [Table("FiscalPeriods")]
    public class FiscalPeriod
    {
        [Key]
        public int FiscalPeriodId { get; set; }

        [Required]
        [Display(Name = "Fiscal Year")]
        public int FiscalYearId { get; set; }

        [Required]
        [StringLength(20)]
        [Display(Name = "Period Code")]
        public string PeriodCode { get; set; } = string.Empty;

        [Required]
        [StringLength(100)]
        [Display(Name = "Period Name")]
        public string PeriodName { get; set; } = string.Empty;

        [Required]
        [StringLength(20)]
        [Display(Name = "Period Type")]
        public string PeriodType { get; set; } = "MONTHLY";

        [Required]
        [Display(Name = "Start Date")]
        [DataType(DataType.Date)]
        public DateTime StartDate { get; set; }

        [Required]
        [Display(Name = "End Date")]
        [DataType(DataType.Date)]
        public DateTime EndDate { get; set; }

        [Display(Name = "Period Number")]
        public int PeriodNumber { get; set; }

        [Display(Name = "Closed")]
        public bool IsClosed { get; set; }

        [Display(Name = "Active")]
        public bool IsActive { get; set; } = true;

        [StringLength(100)]
        public string? ClosedBy { get; set; }

        public DateTime? ClosedDate { get; set; }

        [Required]
        [StringLength(100)]
        public string CreatedBy { get; set; } = string.Empty;

        public DateTime CreatedDate { get; set; } = DateTime.Now;

        [StringLength(100)]
        public string? ModifiedBy { get; set; }

        public DateTime? ModifiedDate { get; set; }

        // Navigation properties
        [ForeignKey("FiscalYearId")]
        public virtual FiscalYear? FiscalYear { get; set; }

        // Display properties (populated by stored procedures and views)
        [NotMapped]
        public string StatusDisplay => IsClosed ? "Closed" : "Open";

        [NotMapped]
        public string? FiscalYearName { get; set; }

        [NotMapped]
        public string? FiscalYearCode { get; set; }

        [NotMapped]
        public bool YearIsClosed { get; set; }

        [NotMapped]
        public string? YearStatus { get; set; }

        [NotMapped]
        public string? PeriodStatus { get; set; }

        [NotMapped]
        public int DaysInPeriod => (EndDate - StartDate).Days + 1;
    }
}
