# NUnit Testing Standards

Goal: fast, readable, independent tests that fail for one reason and say why.

## Contents

1. Project setup
2. Structure and naming
3. Standard tests (AAA)
4. Data-driven tests
5. Assertions
6. Mocking and isolation
7. Organization and attributes
8. Code samples (NSubstitute)
9. Integration tests
10. What to test (and what not)
11. Test review checklist

---

## 1. Project setup

- Separate test project named `[ProjectName].Tests`; test class mirrors the class under test (`Calculator` -> `CalculatorTests`), same folder structure.
- Packages: `Microsoft.NET.Test.Sdk`, `NUnit`, `NUnit3TestAdapter`, `NSubstitute`, `NUnit.Analyzers`, `coverlet.collector`. Install with `dotnet add package <Name>` (check you get current NUnit 4.x).
- Add a `GlobalUsings.cs` so common namespaces are declared once:

```csharp
// GlobalUsings.cs (test project)
global using NUnit.Framework;
global using NSubstitute;
```

- Any other external dependency (a data builder library, a fake `TimeProvider`...) is added with `dotnet add package`, and mentioned in the PR.
- Run tests with `dotnet test`. With coverage: `dotnet test --collect:"XPlat Code Coverage"`.

## 2. Structure and naming

- `[Test]` is mandatory on test methods. Test classes are `public` (and `sealed` is fine).
- Name tests `MethodName_Scenario_ExpectedBehavior`, e.g. `GenerateJwtAsync_WithInvalidPassword_ThrowsUnauthorizedAccessException`.
- `[SetUp]` / `[TearDown]` per test; `[OneTimeSetUp]` / `[OneTimeTearDown]` per class; `[SetUpFixture]` per namespace/assembly.
- The system under test is named `_sut`. Substitutes are private fields declared in `#region Fields`, created in `[SetUp]` (fresh per test = independence). Because they are initialised in `[SetUp]`, declare them with `= null!`.
- Group tests by feature or component inside `#region` blocks.

## 3. Standard tests (AAA)

- One behavior per test. Several asserts are fine if they verify the same behavior (wrap them in `Assert.Multiple`).
- Independent and idempotent: any order, any number of runs. No shared mutable state, no dependence on wall-clock time, randomness, network, or file system.
- Clear assertions that express intent; only the assertions needed to verify the case.
- **Test code uses the Arrange-Act-Assert banner comments** (production code does not use them):

```csharp
[Test]
public void ThisIsMyTest()
{
    //****************** ARRANGE
    // preconditions

    //****************** ACT
    // the action under test

    //****************** ASSERT
    // assertions
}
```

Do **not** end tests with `Assert.Pass()`: a test with no failing assertion already passes, and `Assert.Pass()` throws internally and skips any code after it.

## 4. Data-driven tests

| Attribute | Use for |
| --- | --- |
| `[TestCase(...)]` | Inline data; add `TestName` or `ExpectedResult` when it clarifies |
| `[TestCaseSource]` | Generated or complex data (return `TestCaseData` with `.SetName(...)`) |
| `[Values]` | Simple parameter combinations |
| `[ValueSource]` | Property/method-based values |
| `[Range]` | Sequential numeric values |
| `[Random]` | Random numeric values (log the seed if you use it; prefer deterministic data) |
| `[Combinatorial]` / `[Pairwise]` | Combining several parameters (Pairwise to avoid explosion) |

```csharp
[TestCase(0, 0.00)]
[TestCase(99, 0.00)]
[TestCase(100, 2.00)]
public void CalculateDiscount_BronzeTier_AppliesThreshold(decimal orderValue, decimal expectedDiscount)
{
    //****************** ARRANGE
    var customer = CustomerBuilder.Default().WithTier(LoyaltyTier.Bronze).Build();

    //****************** ACT
    var result = _sut.CalculateDiscount(customer, orderValue);

    //****************** ASSERT
    Assert.That(result, Is.EqualTo(expectedDiscount));
}
```

## 5. Assertions

- Use `Assert.That` with the **constraint model**: `Is.EqualTo`, `Is.SameAs`, `Is.Null`, `Is.True`, `Contains.Item`, `Has.Count.EqualTo`, `Is.TypeOf<T>()`, `Does.StartWith`, `Is.EquivalentTo`, `Throws.TypeOf<T>()`.
- Exceptions: `Assert.Throws<T>` / `Assert.ThrowsAsync<T>` (or `Assert.ThatAsync(..., Throws.TypeOf<T>())`, awaited). Assert on the message or a property only when it is part of the contract.
- Group related assertions: `Assert.Multiple(() => { ... })` so one failure does not hide the others.
- Add descriptive messages when the failure would be ambiguous.
- **Classic asserts** (`Assert.AreEqual`, `CollectionAssert`, `StringAssert`) are legacy: in NUnit 4 they moved to `NUnit.Framework.Legacy` (`ClassicAssert`). Do not write new tests with them; leave existing ones alone unless refactoring.
- **FORBIDDEN: FluentAssertions.** Use NUnit constraints.

## 6. Mocking and isolation

- Use **NSubstitute** to isolate the unit under test; substitute interfaces, not concrete classes.
- **FORBIDDEN: Moq.**
- Do not mock what you own and can build cheaply (value objects, DTOs, domain entities): construct the real thing. Mock boundaries: repositories, gateways, clock, messaging.
- Time: inject `TimeProvider`; use `FakeTimeProvider` (package `Microsoft.Extensions.TimeProvider.Testing`) in tests.
- Complex wiring (rare for unit tests): a DI container is acceptable; keep it per-test.

NSubstitute cheat sheet:

```csharp
var repo = Substitute.For<IUserRepository>();

repo.GetByUsernameAsync("bob", Arg.Any<CancellationToken>()).Returns(user);       // stub (Task<T> handled)
repo.GetByUsernameAsync("ghost", Arg.Any<CancellationToken>()).Returns((User?)null);
repo.SaveAsync(Arg.Any<User>(), Arg.Any<CancellationToken>())
    .Returns(Task.CompletedTask);

repo.Received(1).SaveAsync(Arg.Is<User>(u => u.UserName == "bob"), Arg.Any<CancellationToken>()); // verify call
repo.DidNotReceive().SaveAsync(Arg.Any<User>(), Arg.Any<CancellationToken>());                    // verify no call
repo.GetByUsernameAsync(default!, default).ThrowsAsync(new TimeoutException());                    // see NSubstitute docs for async throws
```

## 7. Organization and attributes

- `[Category("Unit")]` / `[Category("Integration")]` so pipelines can filter.
- `[Order]` only when order is a real requirement (and then ask whether the test design is wrong).
- `[Author("Name")]` to indicate ownership; `[Description]` for extra context.
- `[Explicit]` for tests that must not run automatically (e.g. needs a live system).
- `[Ignore("Reason")]` to skip temporarily - always with a reason and a ticket.
- `[CancelAfter(milliseconds)]` (NUnit 4) as a timeout on anything that could hang.

## 8. Code samples (NSubstitute)

The original team doc showed Moq syntax; these are the corrected versions with NSubstitute.

### Class skeleton

```csharp
namespace Contoso.Auth.Tests;

[TestFixture]
public class AuthenticationServiceTests
{
    #region Fields

    private IUserRepository _userRepository = null!;
    private IPasswordHasher _passwordHasher = null!;
    private IJwtTokenGenerator _jwtTokenGenerator = null!;
    private AuthenticationService _sut = null!;

    #endregion

    [SetUp]
    public void SetUp()
    {
        _userRepository = Substitute.For<IUserRepository>();
        _passwordHasher = Substitute.For<IPasswordHasher>();
        _jwtTokenGenerator = Substitute.For<IJwtTokenGenerator>();

        _sut = new AuthenticationService(_userRepository, _passwordHasher, _jwtTokenGenerator);
    }

    #region GenerateJwtAsync

    // tests here

    #endregion
}
```

### Exception from an async method

```csharp
[Test]
public void GenerateJwtAsync_WithInvalidPassword_ThrowsUnauthorizedAccessException()
{
    //****************** ARRANGE
    var username = "testuser";
    var password = "invalidpassword";
    var user = new User { Id = Guid.NewGuid(), UserName = username, PasswordHash = "hashedpassword" };
    _userRepository.GetByUsernameAsync(username, Arg.Any<CancellationToken>()).Returns(user);
    _passwordHasher.Verify(password, user.PasswordHash).Returns(false);

    //****************** ACT & ASSERT
    Assert.ThrowsAsync<UnauthorizedAccessException>(async () =>
        await _sut.GenerateJwtAsync(username, password, CancellationToken.None));
}
```

### Value returned + interaction verified

```csharp
[Test]
public async Task GenerateJwtAsync_WithValidCredentials_ReturnsJwtToken()
{
    //****************** ARRANGE
    var username = "testuser";
    var password = "password";
    var user = new User { Id = Guid.NewGuid(), UserName = username, PasswordHash = "hashedpassword" };
    var token = "jwttoken";
    _userRepository.GetByUsernameAsync(username, Arg.Any<CancellationToken>()).Returns(user);
    _passwordHasher.Verify(password, user.PasswordHash).Returns(true);
    _jwtTokenGenerator.GenerateToken(user).Returns(token);

    //****************** ACT
    var result = await _sut.GenerateJwtAsync(username, password, CancellationToken.None);

    //****************** ASSERT
    Assert.That(result, Is.EqualTo(token));
    _jwtTokenGenerator.Received(1).GenerateToken(user);
}
```

### Constructor guard clause

```csharp
[Test]
public void Ctor_WithNullRepository_ThrowsArgumentNullException()
{
    //****************** ACT & ASSERT
    var ex = Assert.Throws<ArgumentNullException>(() =>
        new AuthenticationService(null!, _passwordHasher, _jwtTokenGenerator));

    Assert.That(ex.ParamName, Is.EqualTo("userRepository"));
}
```

## 9. Integration tests

- API endpoints: `WebApplicationFactory<Program>` with test configuration; replace external dependencies (payment gateway, message bus) with fakes via `ConfigureTestServices`.
- Database: real engine in a container (Testcontainers) rather than the EF in-memory provider; reset state per test or per fixture.
- Authentication/authorization: test both allowed and denied paths with a test auth handler.
- Tag with `[Category("Integration")]`; keep them out of the fast inner loop.

## 10. What to test (and what not)

Always: the critical paths, domain invariants, edge cases, both success and failure scenarios, null-parameter validation on public entry points.

Skip: trivial properties, framework code, private methods directly (test through the public API), anything whose only assertion would be "the mock was called".

Coverage is a smell detector, not a goal: look at uncovered *branches in business rules*, not the percentage.

## 11. Test review checklist

- [ ] Name follows `MethodName_Scenario_ExpectedBehavior`
- [ ] AAA banners present; one behavior per test
- [ ] Independent: no shared state, no time/random/network/file dependency
- [ ] `Assert.That` constraint model; `Assert.Multiple` for grouped asserts
- [ ] No Moq, no FluentAssertions, no `Assert.Pass()`, no classic asserts in new code
- [ ] Mocks only at boundaries; real objects for domain types
- [ ] Failure and null-parameter cases covered
- [ ] Async tests are `async Task` and awaited (no `async void`, no unawaited tasks)
- [ ] Categories set; `[Ignore]` has reason + ticket
- [ ] Test is deterministic when run 100 times in random order
