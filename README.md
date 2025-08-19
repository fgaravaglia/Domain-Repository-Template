# Repository Description

Put here the description of the repository

## Repository Structure

this repository has the following structure:

```txt
Repository/
|-- docs/
|-- src/
|   |-- Domain/
|   |   |-- Umbrella.Authentication.Domain/
|   |   |   |-- Umbrella.Authentication.Domain.csproj
|   |   |-- Umbrella.Authentication.Infrastructure/
|   |   |   |-- Umbrella.Authentication.Infrastructure.csproj
|   |-- Infrastructure/
|   |   |-- Umbrella.Infrastructure
|   |   |   |-- Umbrella.Infrastructure.csproj
|   |-- WebApi/
|   |   |-- Umbrella.Authentication.WebApi/
|   |   |   |-- Umbrella.Authentication.WebApi.csproj
|   |-- Clients/
|   |   |-- Umbrella.Authentication.WebApi.Client/
|   |   |   |-- Umbrella.Authentication.WebApi.Client.csproj
```

it is divided into documentation (docs folder) ans Source code (src folder).
inside src folder, the code is organized in the following way:

* Domain: it contains the business logic (aka: the domain library) and the infrastructure library for the specific-domain-related concepts, like persistence.
* Infrastructure: it contins all needed libraries related to cross topic and not to business logic.
* WebApi: it contains the source code fro REST api to provide a port for the domain
* Clients: if needed, it contains the clients for Web Api.

## Gemini CLI configuration

### Gemini.md Files Hierarchy

for more details, see:  [https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/configuration.md#context-files-hierarchical-instructional-context]

### Gemini CLi Integration with VS Code

see more details here:  [https://github.com/google-gemini/gemini-cli/blob/main/docs/ide-integration.md]