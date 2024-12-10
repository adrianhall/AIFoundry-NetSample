using Microsoft.AspNetCore.Mvc;
using Sample.Web.Services.Foundry;
using System.ComponentModel.DataAnnotations;

namespace Sample.Web.Controllers;

public class HomeController(IConfiguration configuration, IFoundryService foundryService) : Controller
{
    public IActionResult Index()
    {
        SystemPromptModel viewModel = new() { Prompt = foundryService.SystemPrompt };
        return View(viewModel);
    }

    [HttpPost]
    public IActionResult SetSystemPrompt([FromForm] SystemPromptModel model)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        foundryService.SystemPrompt = model.Prompt;
        TempData["Message"] = "System prompt updated successfully!";
        return RedirectToAction(nameof(Index));
    }

    public IActionResult Inference() => View();

    public IActionResult Configuration() 
    {
        var config = ((IConfigurationRoot)configuration).GetDebugView();
        return Ok(config);
    }

    public class SystemPromptModel
    {
        [Required, StringLength(4096, MinimumLength = 1)]
        public string Prompt { get; set; } = string.Empty;
    }
}
