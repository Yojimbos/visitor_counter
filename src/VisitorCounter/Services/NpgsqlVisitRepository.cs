using Npgsql;

namespace VisitorCounter.Services;

public sealed class NpgsqlVisitRepository : IVisitRepository
{
    private readonly IConfiguration _configuration;

    public NpgsqlVisitRepository(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public async Task<int> RecordVisitAndGetCountAsync(CancellationToken cancellationToken = default)
    {
        var connectionString = _configuration.GetConnectionString("DefaultConnection");
        await using var conn = new NpgsqlConnection(connectionString);
        await conn.OpenAsync(cancellationToken);

        await using var cmd = new NpgsqlCommand(
            "CREATE TABLE IF NOT EXISTS visits (id SERIAL PRIMARY KEY, timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP)",
            conn);
        await cmd.ExecuteNonQueryAsync(cancellationToken);

        cmd.CommandText = "INSERT INTO visits DEFAULT VALUES";
        await cmd.ExecuteNonQueryAsync(cancellationToken);

        cmd.CommandText = "SELECT COUNT(*) FROM visits";
        return Convert.ToInt32(await cmd.ExecuteScalarAsync(cancellationToken));
    }
}