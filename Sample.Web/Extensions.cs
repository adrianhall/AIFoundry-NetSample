using Azure.Core;
using Azure.Identity;

namespace Sample.Web;

public static class Extensions
{
    public static void AddTokenCredential(this IServiceCollection services, IConfigurationSection configuration)
    {
        var clientId = configuration["Azure:ManagedIdentity"];
        var tenantId = configuration["Azure:TenantId"];

        DefaultAzureCredentialOptions options = new();
        if (clientId is not null)
        {
            options.ManagedIdentityClientId = clientId;
        }
        if (tenantId is not null)
        {
            options.TenantId = tenantId;
        }

        services.AddSingleton<TokenCredential>(new DefaultAzureCredential(options));
    }
}
