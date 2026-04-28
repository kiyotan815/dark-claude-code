---
name: php-patterns
description: Modern PHP idioms and patterns (PHP 8.1+) covering PSR standards, type system, namespaces, enums, readonly properties, and dependency management. Framework-agnostic — applies to Laravel, Symfony, plain PHP.
---

# PHP Patterns

Modern PHP (8.1+) idioms for type-safe, maintainable code. Framework-agnostic.

## Foundational Standards

### Always Use `strict_types`

```php
<?php
declare(strict_types=1);

namespace App\Billing;
```

First line of every PHP file. Forces type coercion errors instead of silent conversion.

### PSR Standards

- **PSR-1** — basic coding standard (file structure, naming)
- **PSR-4** — autoloading via Composer (namespace ↔ directory)
- **PSR-12** — extended coding style (formatting)

Use `phpcs` or `php-cs-fixer` to enforce. Don't bikeshed — pick a config and move on.

## Type System

### Always Type Everything

```php
// Good
public function chargeUser(User $user, int $amountCents): PaymentResult
{
    // ...
}

// Bad
public function chargeUser($user, $amount)
{
    // ...
}
```

### Nullable Types

```php
public function findUser(int $id): ?User
{
    // ?User means User|null
}
```

### Union Types (PHP 8.0+)

```php
public function format(int|string $value): string
{
    return (string) $value;
}
```

Use sparingly — usually a sign you should split into two methods.

### Intersection Types (PHP 8.1+)

```php
public function process(Countable&Iterator $collection): void
```

### `never` Return Type (PHP 8.1+)

```php
public function abort(string $reason): never
{
    throw new RuntimeException($reason);
}
```

Tells static analyzers control flow ends here.

### `readonly` Properties (PHP 8.1+) and `readonly` Classes (PHP 8.2+)

```php
final readonly class UserId
{
    public function __construct(public int $value) {}
}
```

Immutable value objects in one line. Combined with constructor property promotion (next section).

## Constructor Property Promotion

```php
// Modern (PHP 8.0+)
final class Order
{
    public function __construct(
        public readonly OrderId $id,
        public readonly Money $total,
        private readonly Clock $clock,
    ) {}
}

// Old style (avoid)
class Order
{
    public OrderId $id;
    public Money $total;
    private Clock $clock;

    public function __construct(OrderId $id, Money $total, Clock $clock)
    {
        $this->id = $id;
        $this->total = $total;
        $this->clock = $clock;
    }
}
```

## Enums (PHP 8.1+)

### Pure Enums

```php
enum Status
{
    case Draft;
    case Published;
    case Archived;
}

$post->status = Status::Published;
```

### Backed Enums

```php
enum Currency: string
{
    case USD = 'USD';
    case JPY = 'JPY';
    case EUR = 'EUR';

    public function decimals(): int
    {
        return match ($this) {
            self::JPY => 0,
            self::USD, self::EUR => 2,
        };
    }
}

Currency::from('USD');         // throws if invalid
Currency::tryFrom('XXX');      // returns null if invalid
```

Use enums anywhere you'd otherwise use string/int constants.

## Match Expressions (Prefer Over `switch`)

```php
$shippingCost = match ($zone) {
    Zone::Domestic => 500,
    Zone::Asia, Zone::Oceania => 1500,
    Zone::Europe, Zone::Americas => 2500,
    default => throw new InvalidZoneException($zone),
};
```

- Strict comparison (`===`)
- Returns a value (no fall-through)
- Compact and exhaustive

## Named Arguments

```php
createUser(
    name: 'Alice',
    email: 'alice@example.com',
    role: Role::Member,
);
```

Self-documenting at call site. Especially valuable when there are many optional parameters.

## Null Safety

### Null Coalescing

```php
$name = $user->name ?? 'Anonymous';
$cache[$key] ??= computeExpensive();    // assign if null
```

### Nullsafe Operator (PHP 8.0+)

```php
$avatarUrl = $user?->profile?->avatarUrl;   // null if any link is null
```

Don't chain too deep — usually means missing abstraction.

## Namespaces and Autoloading

### PSR-4 Layout

```
composer.json:
{
    "autoload": {
        "psr-4": {
            "App\\": "src/"
        }
    }
}

src/Billing/Invoice.php  →  App\Billing\Invoice
```

Run `composer dump-autoload` after adding new directories.

### Use Statements

```php
namespace App\Billing;

use App\Money\Money;
use Psr\Log\LoggerInterface;
use RuntimeException;

final class Invoice
{
    // ...
}
```

Group: project, vendor, global — separated by blank lines. Avoid `use` aliases unless name collision.

## Object Design

### Final by Default

```php
final class PaymentProcessor
{
    // ...
}
```

Inheritance is rarely the right answer. Prefer composition. Open for extension only when explicitly designed for it.

### Interfaces for Boundaries

```php
interface Clock
{
    public function now(): DateTimeImmutable;
}

final class SystemClock implements Clock
{
    public function now(): DateTimeImmutable
    {
        return new DateTimeImmutable();
    }
}

final class FrozenClock implements Clock
{
    public function __construct(private DateTimeImmutable $time) {}

    public function now(): DateTimeImmutable
    {
        return $this->time;
    }
}
```

Inject the interface. Tests use `FrozenClock`. Production uses `SystemClock`.

### Value Objects

```php
final readonly class Email
{
    public function __construct(public string $value)
    {
        if (!filter_var($value, FILTER_VALIDATE_EMAIL)) {
            throw new InvalidArgumentException("Invalid email: $value");
        }
    }
}
```

Validate at construction. Pass `Email` around, not `string`.

## Error Handling

### Specific Exception Hierarchies

```php
class BillingException extends RuntimeException {}
class PaymentDeclined extends BillingException {}
class InsufficientFunds extends PaymentDeclined {}

try {
    $processor->charge($amount);
} catch (InsufficientFunds $e) {
    $this->notifyUser($e);
} catch (PaymentDeclined $e) {
    $this->logDecline($e);
}
```

### Don't Catch `\Throwable` Loosely

`\Throwable` includes `Error` (e.g., `TypeError`). Catch `\Exception` or specific types unless you have a top-level handler.

### `finally` for Cleanup

```php
$file = fopen($path, 'r');
try {
    process($file);
} finally {
    fclose($file);
}
```

## DateTime

### Always `DateTimeImmutable`

```php
$now = new DateTimeImmutable();
$tomorrow = $now->modify('+1 day');   // returns new instance
```

`DateTime` is mutable — bug magnet. Use only when forced by a library.

### Timezone Awareness

```php
$tokyoTime = new DateTimeImmutable('now', new DateTimeZone('Asia/Tokyo'));
```

Store UTC, display in local time. Never assume server timezone.

## Common Pitfalls

### Loose vs Strict Comparison

```php
0 == 'abc'    // true in PHP < 8.0, false in 8.0+
0 === 'abc'   // false (always)

if ($value == 0)    // matches '', '0', 0, false, null in some PHP versions
if ($value === 0)   // exact match
```

**Always use `===` and `!==`.**

### Array vs Object Confusion

```php
$arr = ['name' => 'Alice'];
$arr->name;   // Error — arrays use ['key']

$obj = (object) ['name' => 'Alice'];
$obj['name']; // Error — objects use ->prop
```

Pick consistently — usually objects (typed) over associative arrays.

### Mass Assignment

```php
// Dangerous — accepts any field from $request
$user->fill($request->all());

// Safe — explicit allow list
$user->fill($request->only(['name', 'email']));
```

## Tooling

- **`composer`** — dependency management
- **`phpstan` / `psalm`** — static analysis (level 8 / level 1 = strictest)
- **`php-cs-fixer` / `phpcs`** — code style
- **`rector`** — automated refactoring / upgrade tool

Run `phpstan` in CI. It catches type errors statically that would otherwise need runtime testing.
