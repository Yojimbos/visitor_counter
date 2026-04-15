using VisitorCounter.Services;
using Xunit;

namespace VisitorCounter.Tests;

public sealed class VisitCounterServiceTests
{
    [Fact]
    public async Task RecordVisitAndGetCountAsync_ReturnsRepositoryCount()
    {
        var repository = new FakeVisitRepository(42);
        var service = new VisitCounterService(repository);

        var visitCount = await service.RecordVisitAndGetCountAsync();

        Assert.Equal(42, visitCount);
        Assert.Equal(1, repository.CallCount);
    }

    [Fact]
    public async Task RecordVisitAndGetCountAsync_PassesCancellationTokenToRepository()
    {
        using var cancellationTokenSource = new CancellationTokenSource();
        var repository = new CapturingVisitRepository();
        var service = new VisitCounterService(repository);

        await service.RecordVisitAndGetCountAsync(cancellationTokenSource.Token);

        Assert.Equal(cancellationTokenSource.Token, repository.CapturedToken);
    }

    private sealed class FakeVisitRepository : IVisitRepository
    {
        private readonly int _countToReturn;

        public FakeVisitRepository(int countToReturn)
        {
            _countToReturn = countToReturn;
        }

        public int CallCount { get; private set; }

        public Task<int> RecordVisitAndGetCountAsync(CancellationToken cancellationToken = default)
        {
            CallCount++;
            return Task.FromResult(_countToReturn);
        }
    }

    private sealed class CapturingVisitRepository : IVisitRepository
    {
        public CancellationToken CapturedToken { get; private set; }

        public Task<int> RecordVisitAndGetCountAsync(CancellationToken cancellationToken = default)
        {
            CapturedToken = cancellationToken;
            return Task.FromResult(1);
        }
    }
}
