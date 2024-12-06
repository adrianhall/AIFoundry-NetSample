namespace Sample.Web.Services.Foundry;

public interface IFoundryService
{
    Task<FoundryModelResponse> CallModelAsync(FoundryModelRequest request, CancellationToken cancellationToken = default);
}
