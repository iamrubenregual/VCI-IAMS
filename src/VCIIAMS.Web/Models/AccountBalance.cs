using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace VCIIAMS.Web.Models
{
    [Table("AccountBalances")]
    public class AccountBalance
    {
        [Key]
        public long AccountBalanceId { get; set; }

        [Required]
        public int AccountId { get; set; }

        [Required]
        public int FiscalPeriodId { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal OpeningBalance { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal DebitAmount { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal CreditAmount { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal ClosingBalance { get; set; }

        public DateTime LastUpdated { get; set; } = DateTime.Now;

        // Navigation
        [ForeignKey("AccountId")]
        public virtual ChartOfAccount? Account { get; set; }

        [ForeignKey("FiscalPeriodId")]
        public virtual FiscalPeriod? FiscalPeriod { get; set; }
    }
}

