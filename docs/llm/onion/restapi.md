# REST API Implementation Guide

This comprehensive guide demonstrates how to implement RESTful APIs following Onion Architecture principles using ASP.NET Core. The focus is on creating a clean separation between presentation concerns (HTTP/REST) and business logic while maintaining proper dependency flow and testability.

## 1. Presentation Layer Architecture

```txt
┌─────────────────────────────────────────────┐
│              Web API (Presentation)         │ ← Controllers, DTOs, Middleware
│  ┌─────────────────────────────────────────┐ │
│  │           Infrastructure                │ │ ← Repositories, External Services
│  │  ┌────────────────────────────────────┐ │ │
│  │  │           Application                │ │ │ ← Use Cases, Commands/Queries
│  │  │  ┌─────────────────────────────────┐ │ │ │
│  │  │  │           Domain                │ │ │ │ ← Business Logic, Entities
│  │  │  └─────────────────────────────────┘ │ │ │
│  │  └─────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘

API Dependencies: Presentation → Application → Domain
```

## 2. Project Structure for REST API

### API Project Setup

```bash
# Create Web API project
dotnet new webapi -n YourCompany.YourDomain.API
cd YourCompany.YourDomain.API

# Add necessary references
dotnet add reference ../YourCompany.YourDomain.Application/YourCompany.YourDomain.Application.csproj
dotnet add reference ../YourCompany.YourDomain.Infrastructure/YourCompany.YourDomain.Infrastructure.csproj
```

### API Project Configuration (.csproj)

```xml
<Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <GenerateDocumentationFile>true</GenerateDocumentationFile>
    <DocumentationFile>bin\$(Configuration)\$(TargetFramework)\$(AssemblyName).xml</DocumentationFile>
  </PropertyGroup>

  <ItemGroup>
    <!-- Project References -->
    <ProjectReference Include="..\YourCompany.YourDomain.Application\YourCompany.YourDomain.Application.csproj" />
    <ProjectReference Include="..\YourCompany.YourDomain.Infrastructure\YourCompany.YourDomain.Infrastructure.csproj" />
  </ItemGroup>

  <ItemGroup>
    <!-- ASP.NET Core packages -->
    <PackageReference Include="Microsoft.AspNetCore.Authentication.JwtBearer" Version="8.0.0" />
    <PackageReference Include="Microsoft.AspNetCore.Mvc.Versioning" Version="5.1.0" />
    <PackageReference Include="Microsoft.AspNetCore.Mvc.Versioning.ApiExplorer" Version="5.1.0" />
    <PackageReference Include="Swashbuckle.AspNetCore" Version="6.5.0" />
    
    <!-- Validation and Mapping -->
    <PackageReference Include="FluentValidation.AspNetCore" Version="11.3.0" />
    <PackageReference Include="AutoMapper.Extensions.Microsoft.DependencyInjection" Version="12.0.1" />
    
    <!-- Logging and Monitoring -->
    <PackageReference Include="Serilog.AspNetCore" Version="8.0.0" />
    <PackageReference Include="Serilog.Sinks.Console" Version="5.0.0" />
    <PackageReference Include="Serilog.Sinks.File" Version="5.0.0" />
    
    <!-- Security and Rate Limiting -->
    <PackageReference Include="AspNetCoreRateLimit" Version="5.0.0" />
    <PackageReference Include="Microsoft.AspNetCore.DataProtection" Version="8.0.0" />
  </ItemGroup>

</Project>
```

## 4. DTO Design Patterns

### Request DTOs with Validation

```csharp
namespace YourCompany.YourDomain.API.DTOs.Requests;

/// <summary>
/// Request model for creating a new customer.
/// Contains all required and optional information for customer registration.
/// </summary>
public class CreateCustomerRequest
{
    /// <summary>
    /// The customer's full name.
    /// </summary>
    /// <example>John Smith</example>
    [Required(ErrorMessage = "Name is required")]
    [StringLength(100, MinimumLength = 2, ErrorMessage = "Name must be between 2 and 100 characters")]
    public string Name { get; set; } = string.Empty;

    /// <summary>
    /// The customer's email address (must be unique).
    /// </summary>
    /// <example>john.smith@example.com</example>
    [Required(ErrorMessage = "Email is required")]
    [EmailAddress(ErrorMessage = "Invalid email format")]
    [StringLength(255, ErrorMessage = "Email cannot exceed 255 characters")]
    public string Email { get; set; } = string.Empty;

    /// <summary>
    /// The customer's phone number.
    /// </summary>
    /// <example>+1-555-123-4567</example>
    [Phone(ErrorMessage = "Invalid phone number format")]
    [StringLength(20, ErrorMessage = "Phone number cannot exceed 20 characters")]
    public string? PhoneNumber { get; set; }

    /// <summary>
    /// The customer's date of birth (must be at least 18 years old).
    /// </summary>
    /// <example>1990-05-15</example>
    [Required(ErrorMessage = "Date of birth is required")]
    [DataType(DataType.Date)]
    public DateTime DateOfBirth { get; set; }

    /// <summary>
    /// The customer's address information.
    /// </summary>
    [Required(ErrorMessage = "Address is required")]
    [ValidateNever] // Will be validated by nested validator
    public CreateAddressRequest Address { get; set; } = new();

    /// <summary>
    /// The customer's preferred method of contact.
    /// </summary>
    /// <example>Email</example>
    [Required(ErrorMessage = "Preferred contact method is required")]
    [EnumDataType(typeof(ContactMethod), ErrorMessage = "Invalid contact method")]
    public ContactMethod PreferredContactMethod { get; set; } = ContactMethod.Email;
}
```

### Response DTOs with Documentation

```csharp
namespace YourCompany.YourDomain.API.DTOs.Responses;

/// <summary>
/// Response model containing customer information.
/// </summary>
public class CustomerResponse
{
    /// <summary>
    /// The unique identifier for the customer.
    /// </summary>
    /// <example>550e8400-e29b-41d4-a716-446655440000</example>
    public Guid Id { get; set; }

    /// <summary>
    /// The customer's full name.
    /// </summary>
    /// <example>John Smith</example>
    public string Name { get; set; } = string.Empty;

    /// <summary>
    /// The customer's email address.
    /// </summary>
    /// <example>john.smith@example.com</example>
    public string Email { get; set; } = string.Empty;

    /// <summary>
    /// The customer's phone number.
    /// </summary>
    /// <example>+1-555-123-4567</example>
    public string? PhoneNumber { get; set; }

    /// <summary>
    /// The customer's current status.
    /// </summary>
    /// <example>Active</example>
    public CustomerStatus Status { get; set; }

    /// <summary>
    /// The customer's preferred contact method.
    /// </summary>
    /// <example>Email</example>
    public ContactMethod PreferredContactMethod { get; set; }

    /// <summary>
    /// The date when the customer account was created.
    /// </summary>
    /// <example>2023-01-15T10:30:00Z</example>
    public DateTime CreatedAt { get; set; }

    /// <summary>
    /// The date when the customer information was last updated.
    /// </summary>
    /// <example>2023-06-20T14:45:00Z</example>
    public DateTime? UpdatedAt { get; set; }
}

