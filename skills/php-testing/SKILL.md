---
name: php-testing
description: PHP testing strategies using PHPUnit (primary) and Pest. Covers TDD red-green-refactor, test doubles, data providers, fixtures, and coverage requirements for maintainable PHP test suites.
---

# PHP Testing

TDD-first testing for PHP projects. PHPUnit is the default; Pest noted where relevant.

## TDD Red-Green-Refactor

1. **Red** — write a failing test that describes desired behavior
2. **Green** — minimum code to pass
3. **Refactor** — clean up, keeping tests green

Never write production code without a failing test first.

## Project Layout

```
project/
  src/
    Billing/
      PaymentProcessor.php
  tests/
    Unit/
      Billing/
        PaymentProcessorTest.php
    Integration/
    Feature/                    # Laravel naming
  phpunit.xml
```

`composer.json`:

```json
{
  "autoload-dev": {
    "psr-4": { "Tests\\": "tests/" }
  }
}
```

## PHPUnit Basics

### Test Class Structure

```php
<?php
declare(strict_types=1);

namespace Tests\Unit\Billing;

use App\Billing\PaymentProcessor;
use App\Billing\PaymentDeclined;
use PHPUnit\Framework\TestCase;
use PHPUnit\Framework\Attributes\Test;

final class PaymentProcessorTest extends TestCase
{
    #[Test]
    public function it_charges_a_valid_card(): void
    {
        $processor = new PaymentProcessor(card: $this->validCard());

        $result = $processor->charge(amountCents: 10_000);

        $this->assertTrue($result->isSuccessful());
    }

    #[Test]
    public function it_throws_when_card_is_declined(): void
    {
        $processor = new PaymentProcessor(card: $this->declinedCard());

        $this->expectException(PaymentDeclined::class);

        $processor->charge(amountCents: 10_000);
    }
}
```

- One assertion concept per test (multiple `assert*` lines OK if testing one behavior)
- Use `#[Test]` attribute (PHP 8 attributes) over `test_` prefix
- Test method names read as sentences in snake_case

### Common Assertions

```php
$this->assertSame($expected, $actual);          // ===
$this->assertEquals($expected, $actual);        // == (avoid; loose)
$this->assertTrue($cond);
$this->assertFalse($cond);
$this->assertNull($value);
$this->assertNotNull($value);
$this->assertInstanceOf(User::class, $user);
$this->assertCount(3, $array);
$this->assertContains('item', $array);
$this->assertMatchesRegularExpression('/^\w+$/', $string);
$this->assertGreaterThan(0, $value);
```

Prefer `assertSame` over `assertEquals` — strict comparison catches type bugs.

### Exception Assertions

```php
public function it_throws_on_invalid_input(): void
{
    $this->expectException(InvalidArgumentException::class);
    $this->expectExceptionMessage('Email cannot be empty');
    $this->expectExceptionCode(400);

    new Email('');
}
```

Set up `expectException` **before** the call that throws.

### Setup and Teardown

```php
final class OrderTest extends TestCase
{
    private Clock $clock;

    protected function setUp(): void
    {
        parent::setUp();
        $this->clock = new FrozenClock(new DateTimeImmutable('2026-01-01'));
    }

    protected function tearDown(): void
    {
        // cleanup if needed
        parent::tearDown();
    }
}
```

Avoid `setUpBeforeClass` (static setup) unless truly expensive — leaks state.

## Test Doubles

### When to Use

Isolate the unit under test from collaborators that are:
- External (HTTP, payment gateway)
- Slow (DB, file system)
- Non-deterministic (clock, RNG)

**Don't double the thing you're testing.**

### Stubs (Canned Returns)

```php
$apiClient = $this->createStub(ApiClient::class);
$apiClient->method('fetch')->willReturn(['status' => 'ok']);

$service = new Service($apiClient);
$result = $service->run();
```

### Mocks (Behavior Verification)

```php
$logger = $this->createMock(LoggerInterface::class);
$logger
    ->expects($this->once())
    ->method('error')
    ->with($this->stringContains('payment failed'));

$service = new Service($logger);
$service->processFailingPayment();
```

`expects` asserts the call. `createStub` doesn't.

### Prefer Real Objects When Cheap

For value objects and pure logic, real instances > mocks:

```php
// Bad
$money = $this->createMock(Money::class);
$money->method('amount')->willReturn(100);

// Good
$money = new Money(100, Currency::USD);
```

Mocks couple tests to implementation. Real objects test the actual contract.

### Verifying Doubles

```php
$mailer = $this->createMock(MailerInterface::class);
```

`createMock` verifies the method exists on the interface — prevents drift.

## Data Providers

```php
public static function emailValidationProvider(): array
{
    return [
        'valid simple' => ['alice@example.com', true],
        'valid plus' => ['alice+tag@example.com', true],
        'missing at' => ['aliceexample.com', false],
        'missing domain' => ['alice@', false],
        'empty' => ['', false],
    ];
}

#[Test]
#[DataProvider('emailValidationProvider')]
public function it_validates_email(string $input, bool $expected): void
{
    $this->assertSame($expected, EmailValidator::isValid($input));
}
```

Named keys appear in test output — easy to identify failures.

## Mocking Static / Global State

### Clock Injection

```php
// Bad — coupled to wall clock
public function process(): void
{
    if (date('H') >= 17) { /* ... */ }
}

// Good — injectable
public function __construct(private Clock $clock) {}

public function process(): void
{
    $hour = (int) $this->clock->now()->format('H');
    if ($hour >= 17) { /* ... */ }
}
```

Test with `FrozenClock`. Same pattern for Random, UUIDs, env vars.

### Avoid Global State in Tests

If tests pass individually but fail in bulk → global state leak. Symptoms:
- Static caches not cleared
- DB rows from previous tests
- `$_SERVER` / `$_GET` mutations

Solution: clear or reset between tests, or refactor to inject the dependency.

## Database Tests

### Use Transactions for Isolation

Wrap each test in a transaction that's rolled back in `tearDown`. Most frameworks (Laravel, Symfony) provide traits for this:

```php
use Illuminate\Foundation\Testing\DatabaseTransactions;

final class UserTest extends TestCase
{
    use DatabaseTransactions;
    // ...
}
```

### Factories for Test Data

```php
$user = User::factory()->create([
    'email' => 'alice@example.com',
]);

$admin = User::factory()->admin()->create();   // trait
```

(Laravel example. Symfony has Foundry. Plain PHP: build factory helpers.)

### Avoid Hitting Real External Services

Wrap external HTTP/payment APIs behind interfaces. Test against the interface with stubs. For integration tests, use sandbox/mock servers.

## Pest (Alternative)

Pest is a more concise testing framework built on PHPUnit. Same engine, different syntax:

```php
use App\Billing\PaymentProcessor;

it('charges a valid card', function () {
    $processor = new PaymentProcessor(card: validCard());
    expect($processor->charge(10_000))->toBeSuccessful();
});

it('throws when declined', function () {
    $processor = new PaymentProcessor(card: declinedCard());
    expect(fn() => $processor->charge(10_000))
        ->toThrow(PaymentDeclined::class);
});
```

Pest features: dataset chaining, higher-order tests, plugin ecosystem. Same TDD principles apply.

## Coverage

### `phpunit.xml`

```xml
<phpunit colors="true" failOnWarning="true" failOnRisky="true">
    <testsuites>
        <testsuite name="Unit">
            <directory>tests/Unit</directory>
        </testsuite>
    </testsuites>
    <coverage>
        <report>
            <html outputDirectory="build/coverage"/>
            <text outputFile="build/coverage.txt"/>
        </report>
    </coverage>
    <source>
        <include>
            <directory>src</directory>
        </include>
    </source>
</phpunit>
```

Run with: `phpunit --coverage-html build/coverage`

### Targets

- **Domain logic / value objects**: 95%+
- **Services**: 90%+
- **Controllers**: 80%+
- **Framework glue, DTOs**: lower priority

Coverage is necessary, not sufficient. **Test behavior, not lines.**

## Anti-patterns

### Testing Implementation

```php
// Bad — coupled to internal method
public function test_calls_internal_helper(): void
{
    $service = $this->getMockBuilder(Service::class)
        ->onlyMethods(['internalHelper'])
        ->getMock();
    $service->expects($this->once())->method('internalHelper');
    $service->doThing();
}

// Good — tests the observable outcome
public function test_produces_expected_result(): void
{
    $service = new Service();
    $this->assertSame($expected, $service->doThing());
}
```

### Over-Mocking

If you mock everything, you're testing your mocks. Mock at boundaries (HTTP, DB, time), use real objects within the unit.

### Slow Suites

- Unit tests should run in **milliseconds each**
- Tag slow integration tests: `#[Group('slow')]`
- Run unit suite on save, full suite in CI
- DB transactions over re-seeding

### Brittle Assertions

```php
// Bad — exact match including timestamps
$this->assertSame($expectedFullObject, $actual);

// Good — assert what matters
$this->assertSame('Alice', $actual->name);
$this->assertInstanceOf(DateTimeImmutable::class, $actual->createdAt);
```
