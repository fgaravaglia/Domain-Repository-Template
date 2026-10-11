// Template for a unit-test class. Copy, rename, replace the placeholders.
// Requires GlobalUsings.cs in the test project:
//     global using NUnit.Framework;
//     global using NSubstitute;

namespace Contoso.Customers.Tests;

/// <summary>Unit tests for <see cref="CustomerService"/>.</summary>
[TestFixture]
[Category("Unit")]
public class CustomerServiceTests
{
    #region Fields

    // Why '= null!': these are always assigned in SetUp, which runs before every test.
    private ICustomerRepository _customerRepository = null!;
    private TimeProvider _timeProvider = null!;
    private CustomerService _sut = null!;

    #endregion

    [SetUp]
    public void SetUp()
    {
        // Fresh substitutes per test -> tests stay independent and order-agnostic.
        _customerRepository = Substitute.For<ICustomerRepository>();
        _timeProvider = TimeProvider.System; // swap for FakeTimeProvider when the test depends on time

        _sut = new CustomerService(_customerRepository, _timeProvider);
    }

    #region Constructor

    [Test]
    public void Ctor_WithNullRepository_ThrowsArgumentNullException()
    {
        //****************** ACT & ASSERT
        var ex = Assert.Throws<ArgumentNullException>(() => new CustomerService(null!, _timeProvider));

        Assert.That(ex.ParamName, Is.EqualTo("customerRepository"));
    }

    #endregion

    #region GetByIdAsync

    [Test]
    public async Task GetByIdAsync_WhenCustomerExists_ReturnsCustomer()
    {
        //****************** ARRANGE
        var id = CustomerId.New();
        var customer = Customer.Register(id, "jane@contoso.com");
        _customerRepository.GetByIdAsync(id, Arg.Any<CancellationToken>()).Returns(customer);

        //****************** ACT
        var result = await _sut.GetByIdAsync(id, CancellationToken.None);

        //****************** ASSERT
        Assert.That(result, Is.SameAs(customer));
    }

    [Test]
    public void GetByIdAsync_WhenCustomerDoesNotExist_ThrowsCustomerNotFoundException()
    {
        //****************** ARRANGE
        var id = CustomerId.New();
        _customerRepository.GetByIdAsync(id, Arg.Any<CancellationToken>()).Returns((Customer?)null);

        //****************** ACT & ASSERT
        Assert.ThrowsAsync<CustomerNotFoundException>(async () =>
            await _sut.GetByIdAsync(id, CancellationToken.None));
    }

    #endregion

    #region Register (data-driven)

    [TestCase("")]
    [TestCase("   ")]
    public void Register_WithBlankEmail_ThrowsArgumentException(string email)
    {
        //****************** ACT & ASSERT
        // Why InstanceOf: ArgumentException has subtypes (ArgumentNullException), and blank input may raise either.
        Assert.That(() => Customer.Register(CustomerId.New(), email), Throws.InstanceOf<ArgumentException>());
    }

    [Test]
    public void Register_WithEmailWithoutAtSign_ThrowsDomainException()
    {
        //****************** ACT & ASSERT
        Assert.That(() => Customer.Register(CustomerId.New(), "no-at-sign"), Throws.TypeOf<DomainException>());
    }

    #endregion

    #region Grouped assertions

    [Test]
    public void Register_WithValidData_SetsIdAndEmail()
    {
        //****************** ARRANGE
        var id = CustomerId.New();

        //****************** ACT
        var customer = Customer.Register(id, "jane@contoso.com");

        //****************** ASSERT
        // Why Assert.Multiple: report every failing expectation in one run, not just the first.
        Assert.Multiple(() =>
        {
            Assert.That(customer.Id, Is.EqualTo(id));
            Assert.That(customer.Email, Is.EqualTo("jane@contoso.com"));
        });
    }

    #endregion
}