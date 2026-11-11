using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace VCIIAMS.Web.Models
{
    [Table("JournalEntryTypes")]
    public class JournalEntryType
    {
        [Key]
        public int JournalEntryTypeId { get; set; }

        [Required]
        [StringLength(20)]
        [Display(Name = "Type Code")]
        public string TypeCode { get; set; } = string.Empty;

        [Required]
        [StringLength(100)]
        [Display(Name = "Type Name")]
        public string TypeName { get; set; } = string.Empty;

        [StringLength(255)]
        public string? Description { get; set; }

        [Display(Name = "Active")]
        public bool IsActive { get; set; } = true;

        [Required]
        [StringLength(100)]
        public string CreatedBy { get; set; } = "SYSTEM";

        public DateTime CreatedDate { get; set; } = DateTime.Now;

        [StringLength(100)]
        public string? ModifiedBy { get; set; }

        public DateTime? ModifiedDate { get; set; }

        // Navigation
        public virtual ICollection<JournalEntry>? JournalEntries { get; set; }
    }
}

