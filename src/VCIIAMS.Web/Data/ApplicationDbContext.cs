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

        // Core DbSets
        public DbSet<Department> Departments { get; set; }

        // Accounting DbSets
        public DbSet<AccountType> AccountTypes { get; set; }
        public DbSet<ChartOfAccount> ChartOfAccounts { get; set; }
        public DbSet<FiscalYear> FiscalYears { get; set; }
        public DbSet<FiscalPeriod> FiscalPeriods { get; set; }
        public DbSet<AccountBalance> AccountBalances { get; set; }

        // General Ledger / Journal Entry DbSets
        public DbSet<JournalEntryType> JournalEntryTypes { get; set; }
        public DbSet<JournalEntry> JournalEntries { get; set; }
        public DbSet<JournalEntryLine> JournalEntryLines { get; set; }

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

            // Departments configuration
            modelBuilder.Entity<Department>(entity =>
            {
                entity.ToTable("Departments");
                entity.HasKey(e => e.DepartmentId);
                entity.Property(e => e.DepartmentCode).IsRequired().HasMaxLength(20);
                entity.Property(e => e.DepartmentName).IsRequired().HasMaxLength(100);
                entity.HasIndex(e => e.DepartmentCode).IsUnique();
            });

            // AccountBalances configuration
            modelBuilder.Entity<AccountBalance>(entity =>
            {
                entity.ToTable("AccountBalances");
                entity.HasKey(e => e.AccountBalanceId);
                entity.Property(e => e.OpeningBalance).HasColumnType("decimal(18,2)");
                entity.Property(e => e.DebitAmount).HasColumnType("decimal(18,2)");
                entity.Property(e => e.CreditAmount).HasColumnType("decimal(18,2)");
                entity.Property(e => e.ClosingBalance).HasColumnType("decimal(18,2)");

                entity.HasOne(e => e.Account)
                    .WithMany()
                    .HasForeignKey(e => e.AccountId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(e => e.FiscalPeriod)
                    .WithMany()
                    .HasForeignKey(e => e.FiscalPeriodId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasIndex(e => new { e.AccountId, e.FiscalPeriodId }).IsUnique();
            });

            // JournalEntryTypes configuration
            modelBuilder.Entity<JournalEntryType>(entity =>
            {
                entity.ToTable("JournalEntryTypes");
                entity.HasKey(e => e.JournalEntryTypeId);
                entity.Property(e => e.TypeCode).IsRequired().HasMaxLength(20);
                entity.Property(e => e.TypeName).IsRequired().HasMaxLength(100);
                entity.HasIndex(e => e.TypeCode).IsUnique();
            });

            // JournalEntries configuration
            modelBuilder.Entity<JournalEntry>(entity =>
            {
                entity.ToTable("JournalEntries");
                entity.HasKey(e => e.JournalEntryId);
                entity.Property(e => e.JournalNumber).IsRequired().HasMaxLength(30);
                entity.Property(e => e.Description).IsRequired().HasMaxLength(500);
                entity.Property(e => e.TotalDebit).HasColumnType("decimal(18,2)");
                entity.Property(e => e.TotalCredit).HasColumnType("decimal(18,2)");

                entity.HasOne(e => e.FiscalPeriod)
                    .WithMany()
                    .HasForeignKey(e => e.FiscalPeriodId)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasOne(e => e.JournalEntryType)
                    .WithMany(t => t.JournalEntries)
                    .HasForeignKey(e => e.JournalEntryTypeId)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasOne(e => e.ReversalOfJournalEntry)
                    .WithMany()
                    .HasForeignKey(e => e.ReversalOfJournalEntryId)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasIndex(e => e.JournalNumber).IsUnique();
                entity.HasIndex(e => e.FiscalPeriodId);
                entity.HasIndex(e => e.EntryDate);
                entity.HasIndex(e => e.Status);
            });

            // JournalEntryLines configuration
            modelBuilder.Entity<JournalEntryLine>(entity =>
            {
                entity.ToTable("JournalEntryLines");
                entity.HasKey(e => e.JournalEntryLineId);
                entity.Property(e => e.DebitAmount).HasColumnType("decimal(18,2)");
                entity.Property(e => e.CreditAmount).HasColumnType("decimal(18,2)");

                entity.HasOne(e => e.JournalEntry)
                    .WithMany(j => j.Lines)
                    .HasForeignKey(e => e.JournalEntryId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(e => e.Account)
                    .WithMany()
                    .HasForeignKey(e => e.AccountId)
                    .OnDelete(DeleteBehavior.Restrict);

                entity.HasOne(e => e.Department)
                    .WithMany()
                    .HasForeignKey(e => e.DepartmentId)
                    .OnDelete(DeleteBehavior.SetNull);

                entity.HasIndex(e => new { e.JournalEntryId, e.LineNumber }).IsUnique();
                entity.HasIndex(e => e.AccountId);
            });
        }
    }
}
