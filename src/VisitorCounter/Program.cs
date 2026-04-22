using Azure.Identity;
using Prometheus;
using VisitorCounter.Services;

var builder = WebApplication.CreateBuilder(args);

if (!builder.Environment.IsDevelopment())
{
    builder.Configuration.AddAzureKeyVault(
        new Uri("https://visitor-kv-20260410.vault.azure.net/"),
        new DefaultAzureCredential());
}

// Add services to the container.
builder.Services.AddRazorPages();
builder.Services.AddScoped<IVisitRepository, NpgsqlVisitRepository>();
builder.Services.AddScoped<VisitCounterService>();

var app = builder.Build();
var logger = app.Logger;

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}

// app.UseHttpsRedirection();
app.MapGet("/healthz", () => Results.Ok("ok"));
app.UseHttpMetrics();
app.MapMetrics();
app.UseStaticFiles();
app.UseRouting();
app.UseAuthorization();
app.MapRazorPages();
app.Lifetime.ApplicationStarted.Register(() =>
{
    logger.LogInformation(
        "VisitorCounter started in {Environment}. Connection string configured: {IsConfigured}",
        app.Environment.EnvironmentName,
        !string.IsNullOrWhiteSpace(builder.Configuration.GetConnectionString("DefaultConnection")));
});
app.Run();
