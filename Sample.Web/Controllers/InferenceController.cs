using Azure.AI.Inference;
using Microsoft.AspNetCore.Mvc;
using Sample.Web.Services.Foundry;
using System.ComponentModel.DataAnnotations;

namespace Sample.Web.Controllers;

[ApiController]
[Route("api/inference")]
public class InferenceController(
    IFoundryService foundryService,
    ILogger<InferenceController> logger
    ) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> PostAsync([FromBody] InferenceRequest request, CancellationToken cancellationToken = default)
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
            Messages =
             {
                 new ChatRequestSystemMessage(foundryService.SystemPrompt),
                 new ChatRequestUserMessage(request.Prompt)
             },
            Model = foundryService.ModelName
        };

        logger.LogDebug("Sending completion request");
        var response = await client.CompleteAsync(options, cancellationToken);
        logger.LogDebug("Returning completion response");
        return Ok(response.Value);
    }

    public class InferenceRequest
    {
        [Required, StringLength(4096, MinimumLength = 1)]
        public string Prompt { get; set; } = string.Empty;
    }
}
