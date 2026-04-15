using VisitorCounter.Pages;
using VisitorCounter.Services;
using Xunit;

namespace VisitorCounter.Tests;

public sealed class IndexModelTests
{
    [Fact]
    public async Task OnGetAsync_SetsVisitCountFromService()
    {
        var model = new IndexModel(new VisitCounterService(new StubVisitRepository(7)));

        await model.OnGetAsync();

        Assert.Equal(7, model.VisitCount);
    }

    private sealed class StubVisitRepository : IVisitRepository
    {
        private readonly int _count;

        public StubVisitRepository(int count)
        {
            _count = count;
        }

        public Task<int> RecordVisitAndGetCountAsync(CancellationToken cancellationToken = default)
        {
            return Task.FromResult(_count);
        }
    }
}
