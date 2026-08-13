using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System.Data;
using Dapper;
using VCIIAMS.Web.Data;
using VCIIAMS.Web.Models;

namespace VCIIAMS.Web.Services
{
    public class FiscalPeriodService : IFiscalPeriodService
    {
        private readonly ApplicationDbContext _context;
        private readonly IConfiguration _configuration;
        private readonly string _connectionString;

        public FiscalPeriodService(ApplicationDbContext context, IConfiguration configuration)
        {
            _context = context;
            _configuration = configuration;
            _connectionString = _configuration.GetConnectionString("DefaultConnection")
                ?? throw new InvalidOperationException("Connection string not found.");
        }

        // Fiscal Years
        public async Task<IEnumerable<FiscalYear>> GetAllFiscalYearsAsync(bool includeInactive = false)
        {
            using var connection = new SqlConnection(_connectionString);
            var parameters = new DynamicParameters();
            parameters.Add("@IncludeInactive", includeInactive);

            var fiscalYears = await connection.QueryAsync<FiscalYear>(
                "sp_GetAllFiscalYears",
                parameters,
                commandType: CommandType.StoredProcedure
            );

            return fiscalYears;
        }

        public async Task<FiscalYear?> GetFiscalYearByIdAsync(int fiscalYearId)
        {
            using var connection = new SqlConnection(_connectionString);
            var parameters = new DynamicParameters();
            parameters.Add("@FiscalYearId", fiscalYearId);

            var fiscalYear = await connection.QueryFirstOrDefaultAsync<FiscalYear>(
                "sp_GetFiscalYearById",
                parameters,
                commandType: CommandType.StoredProcedure
            );

            return fiscalYear;
        }

        public async Task<int> CreateFiscalYearAsync(FiscalYear fiscalYear, bool createPeriods, string createdBy)
        {
            using var connection = new SqlConnection(_connectionString);
            var parameters = new DynamicParameters();
            parameters.Add("@FiscalYearCode", fiscalYear.FiscalYearCode);
            parameters.Add("@FiscalYearName", fiscalYear.FiscalYearName);
            parameters.Add("@StartDate", fiscalYear.StartDate);
            parameters.Add("@EndDate", fiscalYear.EndDate);
            parameters.Add("@CreatePeriods", createPeriods);
            parameters.Add("@CreatedBy", createdBy);
            parameters.Add("@NewFiscalYearId", dbType: DbType.Int32, direction: ParameterDirection.Output);

            await connection.ExecuteAsync(
                "sp_CreateFiscalYear",
                parameters,
                commandType: CommandType.StoredProcedure
            );

            return parameters.Get<int>("@NewFiscalYearId");
        }

        public async Task<bool> UpdateFiscalYearAsync(FiscalYear fiscalYear, string modifiedBy)
        {
            using var connection = new SqlConnection(_connectionString);
            var parameters = new DynamicParameters();
            parameters.Add("@FiscalYearId", fiscalYear.FiscalYearId);
            parameters.Add("@FiscalYearCode", fiscalYear.FiscalYearCode);
            parameters.Add("@FiscalYearName", fiscalYear.FiscalYearName);
            parameters.Add("@StartDate", fiscalYear.StartDate);
            parameters.Add("@EndDate", fiscalYear.EndDate);
            parameters.Add("@ModifiedBy", modifiedBy);

            var result = await connection.ExecuteAsync(
                "sp_UpdateFiscalYear",
                parameters,
                commandType: CommandType.StoredProcedure
            );

            return result >= 0;
        }

        public async Task<bool> CloseFiscalYearAsync(int fiscalYearId, string closedBy)
        {
            var fiscalYear = await _context.FiscalYears.FindAsync(fiscalYearId);
            if (fiscalYear == null) return false;

            fiscalYear.IsClosed = true;
            fiscalYear.ClosedBy = closedBy;
            fiscalYear.ClosedDate = DateTime.Now;
            fiscalYear.ModifiedBy = closedBy;
            fiscalYear.ModifiedDate = DateTime.Now;

            await _context.SaveChangesAsync();
            return true;
        }

        public async Task<bool> FiscalYearCodeExistsAsync(string fiscalYearCode, int? excludeFiscalYearId = null)
        {
            var query = _context.FiscalYears.Where(fy => fy.FiscalYearCode == fiscalYearCode);

            if (excludeFiscalYearId.HasValue)
            {
                query = query.Where(fy => fy.FiscalYearId != excludeFiscalYearId.Value);
            }

            return await query.AnyAsync();
        }

        // Fiscal Periods
        public async Task<IEnumerable<FiscalPeriod>> GetAllFiscalPeriodsAsync(int? fiscalYearId = null, bool includeInactive = false)
        {
            using var connection = new SqlConnection(_connectionString);
            var parameters = new DynamicParameters();
            parameters.Add("@FiscalYearId", fiscalYearId);
            parameters.Add("@IncludeInactive", includeInactive);

            var periods = await connection.QueryAsync<FiscalPeriod>(
                "sp_GetAllFiscalPeriods",
                parameters,
                commandType: CommandType.StoredProcedure
            );

            return periods;
        }

        public async Task<FiscalPeriod?> GetFiscalPeriodByIdAsync(int fiscalPeriodId)
        {
            return await _context.FiscalPeriods
                .Include(fp => fp.FiscalYear)
                .FirstOrDefaultAsync(fp => fp.FiscalPeriodId == fiscalPeriodId);
        }

        public async Task<FiscalPeriod?> GetCurrentFiscalPeriodAsync()
        {
            var today = DateTime.Today;
            return await _context.FiscalPeriods
                .Include(fp => fp.FiscalYear)
                .Where(fp => fp.IsActive && !fp.IsClosed)
                .Where(fp => fp.StartDate <= today && fp.EndDate >= today)
                .OrderByDescending(fp => fp.StartDate)
                .FirstOrDefaultAsync();
        }

        public async Task<bool> CloseFiscalPeriodAsync(int fiscalPeriodId, string closedBy)
        {
            using var connection = new SqlConnection(_connectionString);
            var parameters = new DynamicParameters();
            parameters.Add("@FiscalPeriodId", fiscalPeriodId);
            parameters.Add("@ClosedBy", closedBy);

            var result = await connection.ExecuteAsync(
                "sp_CloseFiscalPeriod",
                parameters,
                commandType: CommandType.StoredProcedure
            );

            return result >= 0;
        }

        public async Task<IEnumerable<FiscalPeriod>> GetPeriodsByYearAsync(int fiscalYearId)
        {
            return await _context.FiscalPeriods
                .Where(fp => fp.FiscalYearId == fiscalYearId && fp.IsActive)
                .OrderBy(fp => fp.PeriodNumber)
                .ToListAsync();
        }
    }
}
