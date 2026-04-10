using Microsoft.AspNetCore.Mvc.RazorPages;
using Npgsql;

namespace VisitorCounter.Pages;

public class IndexModel : PageModel
{
    private readonly IConfiguration _configuration;

    public IndexModel(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public int VisitCount { get; set; }

    public async Task OnGetAsync()
    {
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
    }
}