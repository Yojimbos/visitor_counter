using Microsoft.AspNetCore.Mvc.RazorPages;
using Npgsql;
using Prometheus;

namespace VisitorCounter.Pages;

public class IndexModel : PageModel
{
    private static readonly Counter PageVisits = Metrics.CreateCounter(
        "visitor_counter_page_visits_total",
        "Total number of homepage requests handled by the application.");

    private static readonly Gauge StoredVisitCount = Metrics.CreateGauge(
        "visitor_counter_stored_visits",
        "Current number of visit records stored in the database.");

    private readonly IConfiguration _configuration;

    public IndexModel(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public int VisitCount { get; set; }

    public async Task OnGetAsync()
    {
        PageVisits.Inc();

        var connectionString = _configuration.GetConnectionString("DefaultConnection");
        await using var conn = new NpgsqlConnection(connectionString);
        await conn.OpenAsync();

        // Create table if not exists
        await using var cmd = new NpgsqlCommand("CREATE TABLE IF NOT EXISTS visits (id SERIAL PRIMARY KEY, timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP)", conn);
        await cmd.ExecuteNonQueryAsync();

        // Increment counter
        cmd.CommandText = "INSERT INTO visits DEFAULT VALUES";
        await cmd.ExecuteNonQueryAsync();

        // Get count
        cmd.CommandText = "SELECT COUNT(*) FROM visits";
        VisitCount = Convert.ToInt32(await cmd.ExecuteScalarAsync());
        StoredVisitCount.Set(VisitCount);
    }
}
