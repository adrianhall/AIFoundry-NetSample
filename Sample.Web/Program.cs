using Azure.Core;
using Azure.Identity;
using Sample.Web.Services.Foundry;

var builder = WebApplication.CreateBuilder(args);

// Adds a TokenCredential to the services collection.
builder.Services.AddSingleton<TokenCredential>(new DefaultAzureCredential());
builder.Services.AddSingleton<IFoundryService, FoundryService>();
builder.Services.AddControllersWithViews();

var app = builder.Build();

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseAuthorization();
app.MapDefaultControllerRoute();

app.Run();
