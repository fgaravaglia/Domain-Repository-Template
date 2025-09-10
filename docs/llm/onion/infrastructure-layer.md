# Infrastructure Layer Project Setup

You are operating in the generic Infrastructure layer. Here, you will create reusable, cross-cutting components that are not tied to the specific business logic.

## Infrastructure Rules

1. **Domain Agnostic**: The code in this project **MUST NOT** have any knowledge of or dependency on the `Umbrella.Authentication.Domain` project. It must provide generic functionalities.
2. **Cross-Cutting Services**: Implement services for features such as:
    * Logging
    * Caching
    * Email sending
    * Event/Message bus
3. **Abstractions**: Define interfaces for the services you implement (e.g., `ILoggingService`, `ICacheProvider`) to allow the DI container to easily swap implementations.
4. **Configuration**: Provide extension methods for `IServiceCollection` to register the services from this layer in the main application's DI container.

## Project Creation and Configuration

```bash
# Create Infrastructure project
dotnet new classlib -n YourCompany.YourDomain.Infrastructure
cd YourCompany.YourDomain.Infrastructure

# Add references
dotnet add reference ../YourCompany.YourDomain.Domain/YourCompany.YourDomain.Domain.csproj
dotnet add reference ../YourCompany.YourDomain.Application/YourCompany.YourDomain.Application.csproj
```

## Infrastructure Project Configuration (.csproj)

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
    <GenerateDocumentationFile>true</GenerateDocumentationFile>
  </PropertyGroup>

  <ItemGroup>
    <!-- Project references -->
    <ProjectReference Include="..\YourCompany.YourDomain.Domain\YourCompany.YourDomain.Domain.csproj" />
    <ProjectReference Include="..\YourCompany.YourDomain.Application\YourCompany.YourDomain.Application.csproj" />
  </ItemGroup>

  <ItemGroup>
    <!-- Infrastructure-specific packages -->
    <PackageReference Include="Microsoft.EntityFrameworkCore" Version="8.0.0" />
    <PackageReference Include="Microsoft.EntityFrameworkCore.SqlServer" Version="8.0.0" />
    <PackageReference Include="Microsoft.Extensions.Configuration" Version="8.0.0" />
    <PackageReference Include="Microsoft.Extensions.DependencyInjection" Version="8.0.0" />
    <PackageReference Include="Microsoft.Extensions.Logging" Version="8.0.0" />
    <PackageReference Include="AutoMapper" Version="12.0.1" />
    <PackageReference Include="FluentEmail.Core" Version="3.0.2" />
    <PackageReference Include="Newtonsoft.Json" Version="13.0.3" />
  </ItemGroup>

</Project>
```

## Infrastructure Layer Structure

```txt
Infrastructure/
├── Data/
│   ├── Configurations/
│   │   ├── OrderConfiguration.cs
│   │   └── CustomerConfiguration.cs
│   ├── Repositories/
│   │   ├── OrderRepository.cs
│   │   ├── CustomerRepository.cs
│   │   └── GenericRepository.cs
│   ├── ApplicationDbContext.cs
│   └── UnitOfWork.cs
├── Services/
│   ├── EmailService.cs
│   ├── PaymentService.cs
│   └── ExternalApiService.cs
├── External/
│   ├── PaymentGateway/
│   │   ├── StripePaymentService.cs
│   │   └── PayPalPaymentService.cs
│   └── Notifications/
│       ├── SendGridEmailService.cs
│       └── TwilioSmsService.cs
├── Caching/
│   ├── RedisCacheService.cs
│   └── InMemoryCacheService.cs
├── Messaging/
│   ├── RabbitMqEventBus.cs
│   └── AzureServiceBusEventBus.cs
└── DependencyInjection.cs
```

## Infrastructure Implementation Examples

### Repository Implementation

```csharp
namespace YourCompany.YourDomain.Infrastructure.Data.Repositories;

/// <summary>
/// Entity Framework implementation of the order repository.
/// </summary>
public class OrderRepository : GenericRepository<Order, OrderId>, IOrderRepository
{
    public OrderRepository(ApplicationDbContext context) : base(context)
    {
    }

    /// <summary>
    /// Retrieves orders for a specific customer with optional filtering.
    /// </summary>
    /// <param name="customerId">The customer identifier.</param>
    /// <param name="status">Optional order status filter.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>Collection of orders matching the criteria.</returns>
    public async Task<IEnumerable<Order>> GetOrdersByCustomerAsync(
        CustomerId customerId, 
        OrderStatus? status = null, 
        CancellationToken cancellationToken = default)
    {
        var query = Context.Set<Order>()
            .Include(o => o.Items)
            .Where(o => o.CustomerId == customerId);

        if (status.HasValue)
        {
            query = query.Where(o => o.Status == status.Value);
        }

        return await query
            .OrderByDescending(o => o.CreatedAt)
            .ToListAsync(cancellationToken);
    }

    /// <summary>
    /// Gets orders that are pending payment and older than the specified timespan.
    /// </summary>
    /// <param name="olderThan">Timespan threshold for order age.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>Collection of pending orders older than the threshold.</returns>
    public async Task<IEnumerable<Order>> GetPendingOrdersOlderThanAsync(
        TimeSpan olderThan, 
        CancellationToken cancellationToken = default)
    {
        var cutoffDate = DateTime.UtcNow.Subtract(olderThan);
        
        return await Context.Set<Order>()
            .Where(o => o.Status == OrderStatus.Pending && o.CreatedAt < cutoffDate)
            .ToListAsync(cancellationToken);
    }
}
```

### External Service Implementation

```csharp
namespace YourCompany.YourDomain.Infrastructure.Services;

/// <summary>
/// Email service implementation using SendGrid for email delivery.
/// </summary>
public class EmailService : IEmailService
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<EmailService> _logger;
    private readonly string _apiKey;
    private readonly string _fromEmail;

    public EmailService(IConfiguration configuration, ILogger<EmailService> logger)
    {
        _configuration = configuration;
        _logger = logger;
        _apiKey = _configuration["SendGrid:ApiKey"] ?? throw new InvalidOperationException("SendGrid API key not configured");
        _fromEmail = _configuration["SendGrid:FromEmail"] ?? throw new InvalidOperationException("SendGrid from email not configured");
    }

    /// <summary>
    /// Sends order confirmation email to the customer.
    /// </summary>
    /// <param name="order">The order for which to send confirmation.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <exception cref="EmailDeliveryException">Thrown when email delivery fails.</exception>
    public async Task SendOrderConfirmationAsync(Order order, CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("Sending order confirmation email for order {OrderId}", order.Id);

            var client = new SendGridClient(_apiKey);
            
            var emailContent = await GenerateOrderConfirmationContentAsync(order);
            
            var msg = new SendGridMessage()
            {
                From = new EmailAddress(_fromEmail, "Your Company"),
                Subject = $"Order Confirmation - {order.Id}",
                PlainTextContent = emailContent.PlainText,
                HtmlContent = emailContent.Html
            };
            
            msg.AddTo(order.CustomerEmail, order.CustomerName);

            var response = await client.SendEmailAsync(msg, cancellationToken);

            if (response.IsSuccessStatusCode)
            {
                _logger.LogInformation("Order confirmation email sent successfully for order {OrderId}", order.Id);
            }
            else
            {
                var errorContent = await response.Body.ReadAsStringAsync();
                _logger.LogError("Failed to send order confirmation email for order {OrderId}. Status: {StatusCode}, Error: {Error}", 
                    order.Id, response.StatusCode, errorContent);
                throw new EmailDeliveryException($"Failed to send email: {response.StatusCode}");
            }
        }
        catch (Exception ex) when (!(ex is EmailDeliveryException))
        {
            _logger.LogError(ex, "Unexpected error sending order confirmation email for order {OrderId}", order.Id);
            throw new EmailDeliveryException("Failed to send order confirmation email", ex);
        }
    }

    private async Task<EmailContent> GenerateOrderConfirmationContentAsync(Order order)
    {
        // Generate email content using templates
        // Implementation details...
        return new EmailContent("Plain text content", "<html>HTML content</html>");
    }
}
```
