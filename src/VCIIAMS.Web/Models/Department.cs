using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace VCIIAMS.Web.Models
{
    [Table("Departments")]
    public class Department
    {
        [Key]
        public int DepartmentId { get; set; }

        [Required]
        [StringLength(20)]
        [Display(Name = "Department Code")]
        public string DepartmentCode { get; set; } = string.Empty;

        [Required]
        [StringLength(100)]
        [Display(Name = "Department Name")]
        public string DepartmentName { get; set; } = string.Empty;

        [StringLength(500)]
        public string? Description { get; set; }

        [Display(Name = "Parent Department")]
        public int? ParentDepartmentId { get; set; }

        [Display(Name = "Active")]
        public bool IsActive { get; set; } = true;

        [Required]
        [StringLength(100)]
        public string CreatedBy { get; set; } = string.Empty;

        public DateTime CreatedDate { get; set; } = DateTime.Now;

        [StringLength(100)]
        public string? ModifiedBy { get; set; }

        public DateTime? ModifiedDate { get; set; }

        // Navigation
        [ForeignKey("ParentDepartmentId")]
        public virtual Department? ParentDepartment { get; set; }

        public virtual ICollection<Department>? SubDepartments { get; set; }
    }
}

