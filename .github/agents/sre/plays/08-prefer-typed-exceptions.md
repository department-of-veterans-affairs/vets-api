# Play 08: Prefer Typed Exceptions with Domain-Specific Subclasses

## Context
Untyped string raises become generic RuntimeError instances that fall through to 500 error handlers, making client errors indistinguishable from server failures. This misclassification triggers unnecessary alerts, inflates error metrics, and obscures root causes during incident response. Typed exceptions that inherit from semantic base classes automatically route errors to the appropriate HTTP status codes.

## Applies To
- `app/controllers/**/*.rb`
- `app/sidekiq/**/*.rb`
- `lib/**/*.rb`
- `modules/*/app/controllers/**/*.rb`
- `modules/*/lib/**/*.rb`
- `app/services/**/*.rb`

## Investigation Steps
1. Read the full method containing the `raise 'string'` to understand the precondition being enforced -- is it authentication, parameter validation, data integrity, or a service contract?
2. Determine the correct HTTP status code for the failure mode.
3. Check if typed exceptions already exist in the module's namespace or in `Common::Exceptions` for the specific failure mode.
4. Identify whether this raise is in an HTTP request path (controller, service called from controller) or in a background job / rake task, as the impact differs significantly.
5. Look for other `raise 'string'` patterns in the same file or module -- if there are several, recommend creating a domain-specific exception hierarchy. Do not suggest a fix without understanding what semantic error type the string raise represents.

## Severity Assessment
- **CRITICAL:** Untyped raise in controller or service handling authentication, health records, or benefits claims
- **CRITICAL:** Untyped raise that caused or could cause a production incident (misclassified 500 for client error)
- **HIGH:** Untyped raise in any HTTP request path (controller action, service called from controller)
- **HIGH:** Untyped raise in background job where RuntimeError triggers inappropriate retries
- **MEDIUM:** Untyped raise in rake task, utility, or code not in HTTP request path

## Golden Patterns

### Do
Use typed exception classes that map to the correct HTTP status code:
```ruby
# Returns 400 Bad Request
raise Common::Exceptions::ParameterMissing.new('form_number')

# Returns 422 Unprocessable Entity
raise Common::Exceptions::UnprocessableEntity.new(detail: 'Missing user_key')

# Domain-specific failure
raise Paws::DuplicateApplicationError.new('Duplicate application', claim_id: claim_id)
```

Create domain-specific exception hierarchies when a module has multiple failure modes:
```ruby
module Paws
  class PawsError < StandardError
    attr_reader :claim_id, :user_uuid

    def initialize(message, claim_id: nil, user_uuid: nil)
      super(message)
      @claim_id = claim_id
      @user_uuid = user_uuid
    end
  end

  class DuplicateApplicationError < PawsError; end
  class IneligibleApplicantError < PawsError; end
end
```

### Don't
Never use `raise 'string'` in HTTP request paths -- these create RuntimeError and return 500:
```ruby
# BAD: creates RuntimeError, returns 500
raise 'A user_key is required'
raise "Missing/malformed form_number"
raise 'ContactInformationV2 - Missing User VAProfile_ID'
```

## Anti-Patterns

### MHV Session Authentication Failure
**Anti-pattern:**
```ruby
def authenticate
  raise 'A user_key is required for session creation' unless user_key
  # Creates RuntimeError -> falls through to 500 handler
end
```
**Problem:** A missing `user_key` is a data issue (422), not a server failure (500). The RuntimeError fell through the exception handler's type checks and defaulted to 500. Monitoring showed "server errors" while the actual problem was missing authentication data.

**Corrected:**
```ruby
def authenticate
  unless user_key
    raise Common::Exceptions::UnprocessableEntity.new(
      detail: 'Cannot establish MHV session: missing required user_key',
      source: 'MHVLockedSessionClient#authenticate'
    )
  end
  # Returns 422 -- framework recognizes the type automatically
end
```

### IVC CHAMPVA Upload Validation
**Anti-pattern:**
```ruby
def get_form_id
  form_number = params[:form_number]
  raise 'Missing/malformed form_number in params' unless form_number
  FORM_NUMBER_MAP[form_number]
end
```
**Problem:** A missing required parameter should return 400 Bad Request, not 500. The client needs to know which parameter is missing.

**Corrected:**
```ruby
def get_form_id
  form_number = params[:form_number]
  unless form_number
    raise Common::Exceptions::ParameterMissing.new(
      'form_number',
      detail: 'The form_number parameter is required for form uploads'
    )
  end
  # Returns 400 Bad Request with clear error message
  FORM_NUMBER_MAP[form_number]
end
```

### VAProfile Contact Information
**Anti-pattern:**
```ruby
def verify_vet360_id!
  raise 'ContactInformationV2 - Missing User VAProfile_ID' if @user&.vet360_id.blank?
end
```
**Problem:** A missing VAProfile ID is incomplete data setup (422), not a server failure (500). Metrics show this as a server error while the actual problem is a data prerequisite.

**Corrected:**
```ruby
def verify_vet360_id!
  if @user&.vet360_id.blank?
    raise Common::Exceptions::UnprocessableEntity.new(
      detail: 'User must have a VAProfile ID to update contact information',
      source: 'VAProfile::ContactInformation::V2::Service'
    )
  end
  # Returns 422 -- data setup incomplete, not server failure
end
```

## Finding Template
**Prefer Typed Exceptions with Domain-Specific Subclasses** | `CRITICAL`

`{{file_path}}:{{line_number}}` -- `raise '{{message}}'` creates a generic
RuntimeError that falls through to the 500 handler. This {{failure_mode}}
should return {{correct_status_code}}, not 500 Internal Server Error.

**Why this matters:** RuntimeError bypasses all specific exception handlers
and defaults to 500. Client errors become indistinguishable from server
failures. Monitoring triggers false alerts. Error metrics are inflated.

**Suggested fix:**
```ruby
{{suggested_code}}
```

- [ ] Uses typed exception class (not RuntimeError)
- [ ] Maps to correct HTTP status code ({{correct_status_code}})
- [ ] Includes structured metadata (detail, source)
- [ ] Framework exception handler recognizes the new type

[Play: Prefer Typed Exceptions](plays/prefer-typed-exceptions.md)

## Verify Commands
```bash
# No untyped string raises remain in changed file
grep -On "raise\s+['\"][^'\"]+['\"]" {{file_path}} | grep -v "raise [A-Z]" && exit 1 || exit 0

# Run specs for the changed file
bundle exec rspec {{spec_path}}

# RuboCop passes for changed file
bundle exec rubocop {{file_path}}
```

## Related Plays
- Play: Classify Errors (complementary)
- Play: Preserve Cause Chains (complementary)
