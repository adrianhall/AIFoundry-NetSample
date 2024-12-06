using Azure;
using Azure.AI.Inference;
using Azure.AI.Projects;
using Azure.Identity;

namespace Sample.Web.Services.Foundry;

public class FoundryService : IFoundryService
{
    private readonly object _lockObject = new();
    private AIProjectClient? _projectClient;
    private ChatCompletionsClient? _chatCompletionsClient;

    public FoundryService(IConfiguration configuration)
    {
        ConnectionString = configuration.GetConnectionString("AzureAIFoundry")
            ?? throw new InvalidOperationException("The Connection String 'AzureAIFoundry' is not found");

        ModelName = configuration["AzureAIFoundry:ModelName"]
            ?? throw new InvalidOperationException("The configuration value for 'AzureAI:ModelName' is not found");
    }

    /// <summary>
    /// The connection string used by the project client.
    /// </summary>
    public string ConnectionString { get; }

    public string ModelName { get; }

    private AIProjectClient GetProjectClient()
    {
        lock(_lockObject)
        {
            _projectClient ??= new AIProjectClient(ConnectionString, new DefaultAzureCredential());
        }
        return _projectClient;
    }

    private ChatCompletionsClient GetChatCompletionsClient()
    {
        AIProjectClient projectClient = GetProjectClient();
        lock(_lockObject)
        {
            _chatCompletionsClient ??= projectClient.GetChatCompletionsClient();
        }
        return _chatCompletionsClient;
    }

    /// <summary>
    /// Calls the basic model with the given request.
    /// </summary>
    public async Task<FoundryModelResponse> CallModelAsync(FoundryModelRequest request, CancellationToken cancellationToken = default)
    {
        var requestOptions = new ChatCompletionsOptions()
        {
            Messages =
            {
                new ChatRequestSystemMessage(request.SystemPrompt),
                new ChatRequestUserMessage(request.UserPrompt)
            },
            Model = ModelName
        };

        ChatCompletionsClient chatClient = GetChatCompletionsClient();
        Response<ChatCompletions> response = await chatClient.CompleteAsync(requestOptions, cancellationToken);

        return new FoundryModelResponse() 
        {
            SystemPrompt = request.SystemPrompt,
            UserPrompt = request.UserPrompt,
            Response = response.Value.Content,
            CompleteResponse = response.Value
        };
    }
}
