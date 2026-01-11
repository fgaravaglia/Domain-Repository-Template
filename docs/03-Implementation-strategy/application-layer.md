# Application Layer Project Setup

You are operating within the Application Layer. This layer orchestrates use cases by transforming user intent into Domain actions.

## Strategy: Integrity Rules

- Purity & Dependencies: Depends only on the Domain project. Never reference Infrastructure or database-specific packages.
- Orchestration (CQRS): Strictly separate Commands (writes) from Queries (reads).
- Result Pattern: Following Domain rules, all services and handlers must return Result<T> or Option<T> objects instead of throwing business exceptions.
- Validation: Every command must be validated via FluentValidation before reaching the Domain.

## Project Configuration (.csproj)

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
  </PropertyGroup>

  <ItemGroup>
    <ProjectReference Include="..\YourCompany.YourDomain.Domain\YourCompany.YourDomain.Domain.csproj" />
  </ItemGroup>

  <ItemGroup>
    <!-- Abstractions & Tooling -->
    <PackageReference Include="Microsoft.Extensions.DependencyInjection.Abstractions" Version="8.0.0" />
    <PackageReference Include="Microsoft.Extensions.Logging.Abstractions" Version="8.0.0" />
    <PackageReference Include="MediatR" Version="12.0.0" />
    <PackageReference Include="FluentValidation" Version="11.8.0" />
  </ItemGroup>
</Project>
```

- ✅ Reference to Domain project only
- ✅ Application-specific packages (MediatR, FluentValidation, AutoMapper)
- ❌ No Infrastructure project reference
- ❌ No database-specific packages

## Folder Structure (Vertical Slices)

```txt
Application/
├── Common/            # Cross-cutting concerns (Behaviors, Result Pattern)
├── Commands/          # Mutation logic (C in CQRS)
│   └── CreateOrder/   # Feature folder: Command, Handler, Validator
├── Queries/           # Read logic (Q in CQRS)
│   └── GetOrder/      # Query, Handler, and specific DTOs
├── DTOs/              # Input/Output objects (Immutable records)
├── Interfaces/        # Infrastructure service interfaces (e.g., IEmailService)
└── Mappings/          # Conversion logic (Manual mappers or AutoMapper)
```

## Implementation Example: Command Handler

Uses Primary Constructors and the Result Pattern for clean orchestration:

```c#
namespace YourCompany.YourDomain.Application.Commands.CreateOrder;

public record CreateOrderCommand(
    Guid CustomerId,
    List<OrderItemDto> Items) : IRequest<Result<OrderResponseDto>>;

public class CreateOrderCommandHandler(
    IOrderRepository orderRepository,
    IDomainService domainService, // Domain Facade
    ILogger<CreateOrderCommandHandler> logger)
    : IRequestHandler<CreateOrderCommand, Result<OrderResponseDto>>
{
    public async Task<Result<OrderResponseDto>> Handle(CreateOrderCommand request, CancellationToken ct)
    {
        using var scope = logger.BeginScope("Creating order for {CustomerId}", request.CustomerId);

        // Orchestration via Domain Facade (I{Domain}Service)
        // Domain Service returns a Result/DTO as per domain-layer.md rules
        var result = await domainService.ProcessOrderAsync(request.ToDomainDto(), ct);

        if (!result.IsSuccess)
        {
            logger.LogWarning("Order creation failed: {Reason}", result.Error);
            return Result.Failure<OrderResponseDto>(result.Error);
        }

        await orderRepository.AddAsync(result.Value, ct);
        
        return Result.Success(result.Value.ToResponseDto());
    }
}
```

## Implementation Example: Application Service

```csharp
namespace YourCompany.YourDomain.Application.Services;

/// <summary>
/// Application service coordinating order-related operations and cross-cutting concerns.
/// </summary>
public class OrderApplicationService : IOrderApplicationService
{
    private readonly IOrderRepository _orderRepository;
    private readonly IEmailService _emailService;
    private readonly IPaymentService _paymentService;
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<OrderApplicationService> _logger;

    public OrderApplicationService(
        IOrderRepository orderRepository,
        IEmailService emailService,
        IPaymentService paymentService,
        IUnitOfWork unitOfWork,
        ILogger<OrderApplicationService> logger)
    {
        _orderRepository = orderRepository;
        _emailService = emailService;
        _paymentService = paymentService;
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    /// <summary>
    /// Processes order payment with transaction management and notification.
    /// </summary>
    /// <param name="orderId">The order to process payment for.</param>
    /// <param name="paymentDetails">Payment information and method.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>Payment processing result.</returns>
    /// <exception cref="OrderNotFoundException">Thrown when order doesn't exist.</exception>
    /// <exception cref="PaymentProcessingException">Thrown when payment fails.</exception>
    public async Task<PaymentResult> ProcessOrderPaymentAsync(
        OrderId orderId, 
        PaymentDetails paymentDetails, 
        CancellationToken cancellationToken = default)
    {
        using var transaction = await _unitOfWork.BeginTransactionAsync(cancellationToken);
        
        try
        {
            var order = await _orderRepository.GetByIdAsync(orderId, cancellationToken);
            if (order == null)
            {
                throw new OrderNotFoundException(orderId);
            }

            // Process payment through external service
            var paymentResult = await _paymentService.ProcessPaymentAsync(
                order.TotalAmount, 
                paymentDetails, 
                cancellationToken);

            if (paymentResult.IsSuccessful)
            {
                // Update order status
                order.MarkAsPaid(paymentResult.TransactionId);
                await _orderRepository.UpdateAsync(order, cancellationToken);

                // Send confirmation email
                await _emailService.SendOrderConfirmationAsync(order, cancellationToken);

                await transaction.CommitAsync(cancellationToken);
                _logger.LogInformation("Payment processed successfully for order {OrderId}", orderId);
            }
            else
            {
                await transaction.RollbackAsync(cancellationToken);
                _logger.LogWarning("Payment failed for order {OrderId}: {Reason}", orderId, paymentResult.FailureReason);
            }

            return paymentResult;
        }
        catch (Exception ex)
        {
            await transaction.RollbackAsync(cancellationToken);
            _logger.LogError(ex, "Error processing payment for order {OrderId}", orderId);
            throw;
        }
    }
}
```

## Architectural Constraints

- No Domain Objects in Output: Application interfaces must use DTOs for all inputs and outputs.
- Logging Context: Every public method must start with BeginScope containing relevant context.
- Isolation: The Application layer remains agnostic of persistence details (SQL/NoSQL), interacting only with Domain-defined Repository interfaces.
