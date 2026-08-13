using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace VCIIAMS.Web.Models
{
    [Table("FiscalYears")]
    public class FiscalYear
    {
        [Key]
        public int FiscalYearId { get; set; }

        [Required]
        [StringLength(20)]
        [Display(Name = "Fiscal Year Code")]
        public string FiscalYearCode { get; set; } = string.Empty;

        [Required]
        [StringLength(100)]
        [Display(Name = "Fiscal Year Name")]
        public string FiscalYearName { get; set; } = string.Empty;

        [Required]
        [Display(Name = "Start Date")]
        [DataType(DataType.Date)]
        public DateTime StartDate { get; set; }

        [Required]
        [Display(Name = "End Date")]
        [DataType(DataType.Date)]
        public DateTime EndDate { get; set; }

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
        public virtual ICollection<FiscalPeriod>? FiscalPeriods { get; set; }

        // Display properties
        [NotMapped]
        public int PeriodCount { get; set; }

        [NotMapped]
        public string StatusDisplay => IsClosed ? "Closed" : "Open";
    }
}
