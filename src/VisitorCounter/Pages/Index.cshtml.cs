using Microsoft.AspNetCore.Mvc.RazorPages;
using VisitorCounter.Services;

namespace VisitorCounter.Pages;

public class IndexModel : PageModel
{
    private readonly VisitCounterService _visitCounterService;

    public IndexModel(VisitCounterService visitCounterService)
    {
        _visitCounterService = visitCounterService;
    }

    public int VisitCount { get; set; }

    public async Task OnGetAsync()
    {
        var cancellationToken = HttpContext?.RequestAborted ?? CancellationToken.None;
        VisitCount = await _visitCounterService.RecordVisitAndGetCountAsync(cancellationToken);
    }
}
