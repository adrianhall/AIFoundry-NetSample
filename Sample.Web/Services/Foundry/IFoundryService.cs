using Azure.AI.Inference;

namespace Sample.Web.Services.Foundry;

public interface IFoundryService
{
    /// <summary>
    /// The name of the inference model we are using.
    /// </summary>
    string ModelName { get; }
    
    /// <summary>
    /// The system prompt to use for everything.
    /// </summary>
    string SystemPrompt { get; set; }

    /// <summary>
    /// Gets an inference client to use.
    /// </summary>
    ChatCompletionsClient GetInferenceClient();
}
