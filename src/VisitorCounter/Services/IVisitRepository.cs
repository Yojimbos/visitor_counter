namespace VisitorCounter.Services;

public interface IVisitRepository
{
    Task<int> RecordVisitAndGetCountAsync(CancellationToken cancellationToken = default);
}
