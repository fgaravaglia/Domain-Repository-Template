# Requirements to implement Authentication Microservice

this document explains the requirement to create a Microservice to manage authentication process.

## Authentication Domain Layer

As all Domains, Authentication expose a specific interface that wrap the capabilities of the entire domain (the implementation is under APplication Layer).
the methods that needs to be xposed are:

- GenerateUserJwtAsync: a method to generate a valid JWT given username, password and user type.

### GenerateUserJwtAsync

The logic will be:
a. Retrieve the user through IUserRepository using the username.
b. If the user doesn't exist, throw an exception.
c. Verify the password with IPasswordHasher.
d. If the password is not valid, throw an exception.
e. Verify that the user has the role/type corresponding to the requested userType. This is a crucial authorization step: if not, log the issue and throw an Unauthorized Exception
f. If all checks pass, use IJwtTokenGenerator to create the JWT token, including the necessary claims (user ID, roles, and the userType).
g. Return the token string.

### User model

a given user is modeleld thourgh the class User.cs. It has a ValueObject Property called Type, that can have only 2 values:

- StandardUser: A standard interactive user
- ServiceAccount: A non-interactive account for service-to-service

## Authentication Infrastructure Layer

the provider for IUserRepository, defined in the Domain Layer, is JsonUserRepository.

### JsonUserRepository

this implemenation is based on Json file. these are the requirements:

- the constructor needs Folder path and json File Name. so, it will accept an argument of IOptions<JsonRepositoryOptions> and ILogger to support diagnostics.
- Thread-Safety: use a static SemaphoreSlim to manage concurrent access to the JSON file. This ensures that read/write operations are atomic and prevents conflicts between threads and operating system-level locks, as required. Every file access will use await _semaphore.WaitAsync() and_semaphore.Release() in a try...finally block.

The settings will be sotred in the proepr domain section in appSettings.json file:


