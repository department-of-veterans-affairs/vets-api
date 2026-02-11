# Play 19: Validate Before You Fail (Fail Early, Not Late)

## Context
A 50MB file upload begins processing, then discovers an invalid form_number and must roll back, wasting bandwidth, storage, and time. An untyped raise of "Missing param" returns 500, making the client think the server crashed when the actual problem is a missing parameter that should return 400. When validation happens late in a helper, the database has already been written to, so a validation failure requires a manual rollback of mutated state. Failing late costs resources while failing early costs only milliseconds.

## Applies To
- `app/controllers/**/*.rb`
- `modules/*/app/controllers/**/*.rb`
- `app/sidekiq/**/*.rb`
- `modules/*/app/sidekiq/**/*.rb`

## Investigation Steps
1. Read the full controller action to understand the order of operations -- what state mutations (file uploads, DB writes, API calls) occur before validation.
2. Identify all parameters being validated and where validation currently happens (in the action body, in a helper method, in a before_action callback).
3. Determine what typed exception classes are available in the module's namespace or in `Common::Exceptions` for the validation errors being raised.
4. Check if Rails strong parameters (`params.require`) could handle the validation automatically instead of custom validation methods.
5. Verify whether moving validation earlier would break any dependency ordering (e.g., a parameter that depends on a value set by an earlier operation). Do not suggest moving validation without understanding the full action flow. The correct fix depends on what state mutations occur and in what order.

## Severity Assessment
- **CRITICAL:** Validation happens after file upload processing in a controller handling veteran document submissions
- **CRITICAL:** Late validation in code that mutates financial or benefits data before checking parameters
- **HIGH:** Untyped raise for missing parameters in any controller action
- **HIGH:** Validation deferred to helper method called after database writes or API calls
- **MEDIUM:** Validation in getter method that is called before any state mutation

## Golden Patterns

### Do
Validate all inputs at the controller boundary before any state change:
```ruby
def upload
  validate_form_number!  # Validate FIRST
  form_id = FORM_NUMBER_MAP[params[:form_number]]
  # ... proceed with file processing
end
```

Use typed exceptions for validation failures (`ParameterMissing`, `UnprocessableEntity`):
```ruby
raise Common::Exceptions::ParameterMissing, 'form_number' if params[:form_number].blank?
raise Common::Exceptions::UnprocessableEntity.new(
  code: 'INVALID_FORM_NUMBER',
  detail: 'Form number not recognized'
) unless FORM_NUMBER_MAP.key?(params[:form_number])
```

Use Rails strong parameters or `before_action` callbacks:
```ruby
before_action :validate_form_number!, only: [:upload]
```

### Don't
Defer parameter validation to helper methods called after state mutation:
```ruby
# BAD: get_form_id called after file upload has started
def upload
  process_file(params[:file])
  form_id = get_form_id  # validation happens too late
end
```

Mutate state before validation completes:
```ruby
# BAD: database write happens before params are checked
record = Record.create!(data: params[:data])
validate_params!  # too late -- record already created
```

Use untyped string raises (`raise 'Missing param'`) for validation:
```ruby
# BAD: RuntimeError returns 500 instead of 400/422
raise 'Missing/malformed form_number in params'
```

## Anti-Patterns

### IVC CHAMPVA Late Validation
**Anti-pattern:**
```ruby
def get_form_id
  form_number = params[:form_number]
  raise 'Missing/malformed form_number in params' unless form_number
  FORM_NUMBER_MAP[form_number]
end
```
**Problem:** Validates late, after other work has started. Untyped exception: `raise 'string'` creates a RuntimeError that returns 500 instead of 400. File uploads complete before realizing form_number is invalid (wasted bandwidth, storage). Rollback required for partial work (cleanup, orphaned files).

**Corrected:**
```ruby
def upload
  validate_form_number!  # Validate FIRST, before any file processing
  form_id = FORM_NUMBER_MAP[params[:form_number]]
  # ... proceed with file processing
end

private

def validate_form_number!
  raise Common::Exceptions::ParameterMissing, 'form_number' if params[:form_number].blank?
  raise Common::Exceptions::UnprocessableEntity.new(
    code: 'INVALID_FORM_NUMBER',
    detail: 'Form number not recognized'
  ) unless FORM_NUMBER_MAP.key?(params[:form_number])
end
```

## Finding Template
**Validate before you fail (fail early, not late)** | `HIGH`

`{{file_path}}:{{line_number}}` -- {{one_line_violation_description}}

**Why this matters:** Late validation wastes resources (file uploads, DB writes, API calls) before discovering invalid input. Untyped `raise 'string'` returns 500 instead of the correct 4xx status code, misleading clients and inflating server error metrics.

**Suggested fix:**
```ruby
{{suggested_code}}
```

- [ ] Validation happens before any state mutation
- [ ] Uses typed exception (ParameterMissing, UnprocessableEntity)
- [ ] Returns correct 4xx status code (not 500)
- [ ] No side effects occur before validation completes

[Play: Validate before you fail](plays/validate-at-boundaries-fail-fast.md)

## Verify Commands
```bash
# No untyped raise for missing params in changed file
grep -Pni 'raise\s+['"'"'"].*missing.*param' {{file_path}} && exit 1 || exit 0

# No untyped raise for malformed input in changed file
grep -Pni 'raise\s+['"'"'"].*malformed' {{file_path}} && exit 1 || exit 0

# Run specs for the changed file
bundle exec rspec {{spec_path}}

# RuboCop passes for changed file
bundle exec rubocop {{file_path}}
```

## Related Plays
- Play: prefer-typed-exceptions (complementary)
- Play: classify-errors (complementary)
