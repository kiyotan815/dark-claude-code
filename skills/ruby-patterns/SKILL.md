---
name: ruby-patterns
description: Ruby idioms, conventions, and best practices for writing maintainable, expressive Ruby code. Covers core language features, common patterns, and modern Ruby (3.x) features.
---

# Ruby Patterns

Idiomatic Ruby for maintainable, expressive code. Apply when writing or reviewing Ruby code in any framework (Rails, Sinatra, Hanami, plain Ruby).

## Naming Conventions

- `snake_case` for methods, variables, file names
- `CamelCase` for classes and modules
- `SCREAMING_SNAKE_CASE` for constants
- Predicate methods end with `?` (e.g., `valid?`, `empty?`)
- Mutator methods end with `!` (e.g., `save!`, `compact!`) — convention: `!` is the dangerous version
- Boolean attributes: `enabled?`, not `is_enabled`

## Idiomatic Constructs

### Use Symbols for Identifiers

```ruby
# Good — symbols are immutable and memory-efficient
status = :active
user[:name]

# Avoid — strings allocate per literal
status = "active"
```

### Block-Based Iteration (no `for` loops)

```ruby
# Good
users.each { |u| puts u.name }
users.map(&:name)
users.select(&:active?)
users.reject { |u| u.deleted_at.present? }

# Avoid
for user in users
  puts user.name
end
```

### Memoization with `||=`

```ruby
def expensive_lookup
  @result ||= fetch_from_db
end
```

Note: `||=` doesn't memoize `false` or `nil`. Use `defined?` for those:

```ruby
def cached_value
  return @value if defined?(@value)
  @value = compute_possibly_nil
end
```

### Safe Navigation `&.`

```ruby
user&.profile&.avatar_url  # nil if any link in chain is nil
```

### Conditional Assignment

```ruby
config[:timeout] ||= 30      # set if nil/false
result = data || default     # fallback
```

## String Handling

### Frozen String Literals

Add to top of every file:

```ruby
# frozen_string_literal: true
```

Strings become immutable, faster, and safer.

### String Interpolation Over Concatenation

```ruby
# Good
"Hello, #{name}!"

# Avoid
"Hello, " + name + "!"
```

### Heredocs for Multi-line

```ruby
sql = <<~SQL
  SELECT id, name
  FROM users
  WHERE active = true
SQL
```

`<<~` (squiggly heredoc) strips leading whitespace.

## Method Design

### Keyword Arguments for Clarity

```ruby
# Good — call site is self-documenting
def create_user(name:, email:, role: :member)
  # ...
end

create_user(name: "Alice", email: "a@example.com")

# Avoid for >2 args
def create_user(name, email, role = :member)
```

### Short Methods, Single Responsibility

Target: methods under ~10 lines. If longer, extract.

### Return Values

Ruby returns the last expression. Don't write explicit `return` unless early-returning.

```ruby
def discount_for(user)
  return 0 if user.guest?
  user.premium? ? 0.2 : 0.1
end
```

## Pattern Matching (Ruby 3.0+)

```ruby
case payload
in { type: "user", id: Integer => id, name: String => name }
  User.new(id:, name:)
in { type: "order", items: Array => items }
  Order.new(items:)
else
  raise ArgumentError
end
```

Powerful for parsing structured data (API responses, config).

## Modules

### Mixins

```ruby
module Trackable
  def track!
    Tracker.log(self)
  end
end

class Order
  include Trackable
end
```

### Namespace Modules

```ruby
module Billing
  class Invoice
    # ...
  end

  class Payment
    # ...
  end
end

invoice = Billing::Invoice.new
```

## Error Handling

### Specific Exception Classes

```ruby
class PaymentDeclined < StandardError; end
class InsufficientFunds < PaymentDeclined; end

begin
  charge!
rescue InsufficientFunds => e
  notify_user(e.message)
rescue PaymentDeclined => e
  log_decline(e)
end
```

### Don't Rescue `Exception`

```ruby
# Bad — catches SystemExit, NoMemoryError, Interrupt
rescue Exception

# Good — catches normal errors
rescue StandardError
# or simply:
rescue
```

### Use `ensure` for Cleanup

```ruby
def process(file)
  f = File.open(file)
  do_work(f)
ensure
  f&.close
end
```

## Modern Ruby Features

### Endless Methods (Ruby 3.0+)

```ruby
def square(x) = x * x
def full_name = "#{first_name} #{last_name}"
```

Use only for true one-liners.

### Hash Shorthand (Ruby 3.1+)

```ruby
name = "Alice"
age = 30
user = { name:, age: }   # equivalent to { name: name, age: age }
```

### Numbered Block Parameters

```ruby
[1, 2, 3].map { _1 * 2 }   # [2, 4, 6]
```

Use sparingly — kills readability past 1 parameter.

## Common Pitfalls

### `nil` vs `false` vs `empty?`

```ruby
"".nil?      # false
"".empty?    # true
[].empty?    # true
nil.empty?   # NoMethodError

# Safest check for "nothing":
value.blank?    # Rails-only — true for nil, "", " ", [], {}
value.present?  # opposite of blank?
```

### Mutating vs Non-Mutating

```ruby
arr = [3, 1, 2]
arr.sort     # returns new sorted array, arr unchanged
arr.sort!    # mutates arr in place

str = "hi"
str.upcase   # returns "HI", str unchanged
str.upcase!  # mutates str
```

Be explicit about which you want.

### Symbol vs String Keys in Hashes

```ruby
h = { "name" => "Alice" }
h[:name]   # nil — different key

# Rails: HashWithIndifferentAccess solves this
# Plain Ruby: pick one and stick with it
```

## Style References

- [Ruby Style Guide](https://rubystyle.guide/)
- Use `rubocop` for automated style checks
- `standard` gem for less-bikeshed configuration
