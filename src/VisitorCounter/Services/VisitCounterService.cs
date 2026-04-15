using Prometheus;

namespace VisitorCounter.Services;

public sealed class VisitCounterService
{
    private static readonly Counter PageVisits = Metrics.CreateCounter(
        "visitor_counter_page_visits_total",
        "Total number of homepage requests handled by the application.");

    private static readonly Gauge StoredVisitCount = Metrics.CreateGauge(
        "visitor_counter_stored_visits",
        "Current number of visit records stored in the database.");

    private readonly IVisitRepository _visitRepository;

    public VisitCounterService(IVisitRepository visitRepository)
    {
        _visitRepository = visitRepository;
    }

    public async Task<int> RecordVisitAndGetCountAsync(CancellationToken cancellationToken = default)
    {
        PageVisits.Inc();
        var visitCount = await _visitRepository.RecordVisitAndGetCountAsync(cancellationToken);
        StoredVisitCount.Set(visitCount);
        return visitCount;
    }
}