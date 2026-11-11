using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System.Data;
using Dapper;
using VCIIAMS.Web.Data;
using VCIIAMS.Web.Models;

namespace VCIIAMS.Web.Services.HelperService {
    public static class BadgeHelper
    {
        public static string CategoryBadge(string category) =>
            category switch
            {
                "ASSET"     => "<span class='badge bg-success'>Asset</span>",
                "LIABILITY" => "<span class='badge bg-danger'>Liability</span>",
                "EQUITY"    => "<span class='badge bg-primary'>Equity</span>",
                "REVENUE"   => "<span class='badge bg-success'>Revenue</span>",
                "EXPENSE"   => "<span class='badge bg-warning'>Expense</span>",
                _           => $"<span class='badge bg-secondary'>{category}</span>"
            };

        public static string JournalStatusBadge(string status) =>
            status switch
            {
                "POSTED"    => "<span class='badge bg-success'><i class='bi bi-check-circle me-1'></i>Posted</span>",
                "DRAFT"     => "<span class='badge bg-warning text-dark'><i class='bi bi-pencil me-1'></i>Draft</span>",
                "SUBMITTED" => "<span class='badge bg-info'><i class='bi bi-clock me-1'></i>Submitted</span>",
                "REVERSED"  => "<span class='badge bg-secondary'><i class='bi bi-arrow-counterclockwise me-1'></i>Reversed</span>",
                "VOID"      => "<span class='badge bg-danger'><i class='bi bi-x-circle me-1'></i>Void</span>",
                _           => $"<span class='badge bg-secondary'>{status}</span>"
            };
    }
}
