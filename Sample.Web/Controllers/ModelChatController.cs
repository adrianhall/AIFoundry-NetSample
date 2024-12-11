using Azure.AI.Inference;
using Microsoft.AspNetCore.Mvc;
using Sample.Web.Services.Foundry;
using System.ComponentModel.DataAnnotations;

namespace Sample.Web.Controllers;

[ApiController]
[Route("api/modelchat")]
public class ModelChatController(
    IFoundryService foundryService,
    ILogger<ModelChatController> logger) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> PostAsync([FromBody] ChatRequest request, CancellationToken cancellationToken = default)
    {
        logger.LogDebug("Received inference request: {Prompt}", request.Prompt);

        if (!ModelState.IsValid)
        {
            logger.LogDebug("BadRequest due to invalid model state");
            return BadRequest(ModelState);
        }

        logger.LogDebug("Getting inference client");
        var client = foundryService.GetInferenceClient();

        logger.LogDebug("Building completions options");
        var options = new ChatCompletionsOptions()
        {
            Messages = [ new ChatRequestSystemMessage(foundryService.SystemPrompt) ],
            Model = foundryService.ModelName
        };

        foreach (var message in request.Messages)
        {
            options.Messages.Add(message.IsResponse
                ? new ChatRequestAssistantMessage(message.Prompt)
                : new ChatRequestUserMessage(message.Prompt));
        }
        options.Messages.Add(new ChatRequestUserMessage(request.Prompt));

        logger.LogDebug("Sending completion request");
        var response = await client.CompleteAsync(options, cancellationToken);
        logger.LogDebug("Returning completion response");
        return Ok(response.Value);
    }

    /// <summary>
    /// The model for the chat history.
    /// </summary>
    public class ChatHistoryModel
    {
        public bool IsResponse { get; set; }

        [Required, StringLength(4096, MinimumLength = 1)]
        public string Prompt { get; set; } = string.Empty;
    }

    public class ChatRequest
    {
        public IEnumerable<ChatHistoryModel> Messages { get; set; } = [];

        [Required, StringLength(4096, MinimumLength = 1)]
        public string Prompt { get; set; } = string.Empty;
    }
}
