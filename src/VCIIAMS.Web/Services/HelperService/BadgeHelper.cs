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
    }
}
