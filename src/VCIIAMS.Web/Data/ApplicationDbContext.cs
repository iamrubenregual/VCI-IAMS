using Microsoft.EntityFrameworkCore;
using VCIIAMS.Web.Models;

namespace VCIIAMS.Web.Data
{
    public class ApplicationDbContext : DbContext
    {
        public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
            : base(options)
        {
        }

        // Accounting DbSets
        public DbSet<AccountType> AccountTypes { get; set; }
        public DbSet<ChartOfAccount> ChartOfAccounts { get; set; }
        public DbSet<FiscalYear> FiscalYears { get; set; }
        public DbSet<FiscalPeriod> FiscalPeriods { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            // ChartOfAccounts configuration
            modelBuilder.Entity<ChartOfAccount>(entity =>
            {
                entity.ToTable("ChartOfAccounts");
                entity.HasKey(e => e.AccountId);

                entity.Property(e => e.AccountCode)
                    .IsRequired()
                    .HasMaxLength(50);

                entity.Property(e => e.AccountName)
                    .IsRequired()
                    .HasMaxLength(200);

                entity.Property(e => e.OpeningBalance)
                    .HasColumnType("decimal(18,2)");

                entity.HasOne(e => e.AccountType)
                    .WithMany(at => at.ChartOfAccounts)
                    .HasForeignKey(e => e.AccountTypeId)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasOne(e => e.ParentAccount)
                    .WithMany(p => p.ChildAccounts)
                    .HasForeignKey(e => e.ParentAccountId)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasIndex(e => e.AccountCode).IsUnique();
            });

            // AccountTypes configuration
            modelBuilder.Entity<AccountType>(entity =>
            {
                entity.ToTable("AccountTypes");
                entity.HasKey(e => e.AccountTypeId);

                entity.Property(e => e.TypeCode)
                    .IsRequired()
                    .HasMaxLength(20);

                entity.HasIndex(e => e.TypeCode).IsUnique();
            });

            // FiscalYears configuration
            modelBuilder.Entity<FiscalYear>(entity =>
            {
                entity.ToTable("FiscalYears");
                entity.HasKey(e => e.FiscalYearId);

                entity.Property(e => e.FiscalYearCode)
                    .IsRequired()
                    .HasMaxLength(20);

                entity.HasIndex(e => e.FiscalYearCode).IsUnique();
            });

            // FiscalPeriods configuration
            modelBuilder.Entity<FiscalPeriod>(entity =>
            {
                entity.ToTable("FiscalPeriods");
                entity.HasKey(e => e.FiscalPeriodId);

                entity.Property(e => e.PeriodCode)
                    .IsRequired()
                    .HasMaxLength(20);

                entity.HasOne(e => e.FiscalYear)
                    .WithMany(fy => fy.FiscalPeriods)
                    .HasForeignKey(e => e.FiscalYearId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasIndex(e => new { e.FiscalYearId, e.PeriodCode }).IsUnique();
            });
        }
    }
}
