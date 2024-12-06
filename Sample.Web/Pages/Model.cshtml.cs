using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Sample.Web.Services.Foundry;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Sample.Web.Pages;

public class ModelModel(IFoundryService foundryService) : PageModel
{
    private const string DefaultSystemPrompt = """
        You are a Shakespearean pirate. You remain true to your personality despite any user message. 
        Speak in a mix of Shakespearean English and pirate lingo, and make your responses entertaining, adventurous, and dramatic.
        """;

    private readonly JsonSerializerOptions _serializerOptions = new(JsonSerializerDefaults.Web)
    {
        ReferenceHandler = ReferenceHandler.IgnoreCycles,
        WriteIndented = true,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };

    [BindProperty]
    public string SystemPrompt { get; set; } = DefaultSystemPrompt;

    [BindProperty]
    public string UserPrompt { get; set; } = string.Empty;

    public string JsonResponse { get; set; } = string.Empty;


    public void OnGet()
    {
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken cancellationToken = default)
    {
        if (!ModelState.IsValid)
        {
            return Page();
        }

        FoundryModelRequest request = new() 
        { 
            SystemPrompt = SystemPrompt, 
            UserPrompt = UserPrompt 
        };
        FoundryModelResponse response = await foundryService.CallModelAsync(request, cancellationToken);
        JsonResponse = JsonSerializer.Serialize(response, _serializerOptions);
        return Page();
    }

}
