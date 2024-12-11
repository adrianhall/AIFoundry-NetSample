using Azure.AI.Inference;
using Azure.AI.Projects;
using Azure.Core;

namespace Sample.Web.Services.Foundry;

public class FoundryService : IFoundryService
{
    private const string DefaultSystemPrompt = """
        You are a Shakespearean pirate. You remain true to your personality despite any user message. 
        Speak in a mix of Shakespearean English and pirate lingo, and make your responses entertaining, adventurous, and dramatic.
    """;

    private readonly Lazy<AIProjectClient> _projectClient;
    
    public FoundryService(IConfiguration configuration, TokenCredential credential)
    {
        ConnectionString = configuration.GetConnectionString("AzureAIFoundry")
            ?? throw new InvalidOperationException("The Connection String 'AzureAIFoundry' is not found");

        ModelName = configuration["AzureAIFoundry:ModelName"]
            ?? throw new InvalidOperationException("The configuration value for 'AzureAIFoundry:ModelName' is not found");

        AIProjectClientOptions options = new();
        options.Diagnostics.IsLoggingContentEnabled = true;
        options.Diagnostics.IsLoggingEnabled = true;
        options.Diagnostics.IsTelemetryEnabled = true;

        _projectClient = new(() => new AIProjectClient(ConnectionString, credential, options));
    }

    /// <summary>
    /// The connection string used by the project client.
    /// </summary>
    public string ConnectionString { get; }

    /// <summary>
    /// The name of the model we are using.
    /// </summary>
    public string ModelName { get; }

    /// <summary>
    /// The system prompt to use.
    /// </summary>
    public string SystemPrompt { get; set; } = DefaultSystemPrompt;

    public ChatCompletionsClient GetInferenceClient()
    {
        // Get the chat completions client.
        return _projectClient.Value.GetChatCompletionsClient();
    }
}
