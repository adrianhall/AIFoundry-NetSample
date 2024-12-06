namespace Sample.Web.Services.Foundry;

public class FoundryModelRequest
{
    public required string SystemPrompt { get; set; }
    public required string UserPrompt { get; set; }
}

public class FoundryModelResponse
{
    public string SystemPrompt { get; set; } = string.Empty;
    public string UserPrompt { get; set; } = string.Empty;
    public string Response { get; set; } = string.Empty;
    public object? CompleteResponse { get; set; }
}
