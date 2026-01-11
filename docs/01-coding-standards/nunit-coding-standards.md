# NUnit Best Practices

Your goal is to help me write effective unit tests with NUnit, covering both standard and data-driven testing approaches.

## Project Setup

- Use a separate test project with naming convention [ProjectName].Tests
- Reference Microsoft.NET.Test.Sdk, NUnit, and NUnit3TestAdapter packages
- Create test classes that match the classes being tested (e.g., CalculatorTests for Calculator)
- Use .NET SDK test commands: dotnet test for running tests
- create the global using file, to declar main dependency once for all.
- identify external dependecies (like NSubistute or FLuentAssert) and add them to csproj using the command: dotnet add package {Name of library}

## Test Structure

- **MANDATORY**: Use [Test] attribute for test methods
- Follow the Arrange-Act-Assert (AAA) pattern
- Name tests using the pattern MethodName_Scenario_ExpectedBehavior
- Use [SetUp] and [TearDown] for per-test setup and teardown
- Use [OneTimeSetUp] and [OneTimeTearDown] for per-class setup and teardown
- Use [SetUpFixture] for assembly-level setup and teardown

## Standard Tests

- Keep tests focused on a single behavior
- Avoid testing multiple behaviors in one test method
- Use clear assertions that express intent
- Include only the assertions needed to verify the test case
- Make tests independent and idempotent (can run in any order)
- Avoid test interdependencies
- Write all tests using the format AAA:

```c#
public void ThisIsmyTest()
{
    //****************** ARRANGE
    // put here the preconditions

    //****************** ACT
    // do the action to test

    //****************** ASSERT
    // write here the assert statements
    Assert.Pass();
}
```

## Data-Driven Tests

- Use [TestCase] for inline test data
- Use [TestCaseSource] for programmatically generated test data
- Use [Values] for simple parameter combinations
- Use [ValueSource] for property or method-based data sources
- Use [Random] for random numeric test values
- Use [Range] for sequential numeric test values
- Use [Combinatorial] or [Pairwise] for combining multiple parameters

## Assertions

- Use Assert.That with constraint model (preferred NUnit style)
- Use constraints like Is.EqualTo, Is.SameAs, Contains.Item, Has.Count.EqualTo
- Use Assert.AreEqual for simple value equality (classic style)
- Use CollectionAssert for collection comparisons
- Use StringAssert for string-specific assertions
- Use Assert.Throws<T> or Assert.ThrowsAsync<T> to test exceptions
- Use descriptive messages in assertions for clarity on failure
- **FORBIDDEN**: usage of FLuentAssertion Library.

## Mocking and Isolation

- Consider using NSubstitute alongside NUnit
- Mock dependencies to isolate units under test
- Use interfaces to facilitate mocking
- Consider using a DI container for complex test setups
- **FORBIDDEN**: usage of Moq Library.

## Test Organization

- Group tests by feature or component inside specific region
- Use categories with [Category("CategoryName")]
- Use [Order] to control test execution order when necessary
- Use [Author("DeveloperName")] to indicate ownership
- Use [Description] to provide additional test information
- Consider [Explicit] for tests that shouldn't run automatically
- Use [Ignore("Reason")] to temporarily skip tests

## Code Samples

here some code examples to follow.

### Testing an exception raise for async methods

```c#
    [Test]
    public async Task GenerateJwtAsync_WithInvalidPassword_ThrowsUnauthorizedAccessException()
    {
        //********* ARRANGE
        var username = "testuser";
        var password = "invalidpassword";
        var user = new User { Id = new Guid(), UserName = username, PasswordHash = "hashedpassword" };
        _userRepositoryMock.Setup(x => x.GetByUsernameAsync(username, It.IsAny<CancellationToken>())).ReturnsAsync(user);
        _passwordHasherMock.Setup(x => x.Verify(password, user.PasswordHash)).Returns(false);

        //********* ACT & ASSERT
        Assert.ThrowsAsync<UnauthorizedAccessException>(async () =>
           await _authenticationService.GenerateJwtAsync(username, password, CancellationToken.None));
        Assert.Pass();
    }
```

### Testing a string has expected value

```c#
    [Test]
    public async Task GenerateJwtAsync_WithValidCredentials_ReturnsJwtToken()
    {
        // Arrange
        var username = "testuser";
        var password = "password";
        var user = new User { Id = new Guid(), UserName = username, PasswordHash = "hashedpassword" };
        var token = "jwttoken";
        _userRepositoryMock.Setup(x => x.GetByUsernameAsync(username, It.IsAny<CancellationToken>())).ReturnsAsync(user);
        _passwordHasherMock.Setup(x => x.Verify(password, user.PasswordHash)).Returns(true);
        _jwtTokenGeneratorMock.Setup(x => x.GenerateToken(user)).Returns(token);

        // Act
        var result = await _authenticationService.GenerateJwtAsync(username, password, CancellationToken.None);

        // Assert
        Assert.That(result, Is.Not.Null.Or.Empty);
        Assert.That(result, Is.EqualTo(token));
        Assert.Pass();
    }
```
