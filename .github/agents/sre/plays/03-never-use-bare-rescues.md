# Play 03: Never Use Broad or Bare Rescues

## Context
A bare rescue swallows everything: typos become nil, Ctrl+C hangs processes, and SystemExit is ignored. APM never sees the error, so code bugs ship to production with zero alerts and zero visibility. A BGS timeout returns nil, missing data returns nil, and a database error returns nil, making it impossible to tell which failure occurred. A NoMethodError from a code bug looks like "veteran has no file number," leading to the wrong diagnosis and the wrong fix.

## Applies To
- `app/controllers/**/*.rb`
- `app/sidekiq/**/*.rb`
- `app/models/**/*.rb`
- `modules/*/app/controllers/**/*.rb`
- `modules/*/app/models/**/*.rb`
- `modules/*/app/sidekiq/**/*.rb`
- `lib/**/*.rb`

## Investigation Steps
1. Read the full method to understand what code is protected.
2. Identify exception types the called methods can raise.
3. Determine if at boundary (controller/job) or inner code.
4. Check if typed exceptions exist in the module's namespace.
5. Check what callers expect -- nil returns or exceptions.

## Severity Assessment
- **CRITICAL**: Bare rescue in code handling PII, PHI, or financial data
- **CRITICAL**: Bare rescue in controller actions handling user requests
- **CRITICAL**: Bare rescue + nil return in code calling external services
- **HIGH**: Bare rescue in service layer calling external APIs
- **MEDIUM**: Bare rescue in internal utility with no external dependencies

## Golden Patterns

### Do
Catch only expected failures:
```ruby
rescue BGS::ServiceError, Faraday::Error => e
```

Use `rescue StandardError => e` at controller boundary as outermost handler only:
```ruby
rescue StandardError => e
  # Only at controller action or Sidekiq perform boundaries
end
```

### Don't
Never use bare `rescue` -- catches everything including typos and system signals:
```ruby
# BAD
rescue
  nil
end
```

Never use `rescue => e` without specifying error type -- identical to bare rescue:
```ruby
# BAD
rescue => e
  Rails.logger.error(e.message)
end
```

Never use `rescue Exception` -- catches Interrupt, SystemExit, and load errors:
```ruby
# BAD
rescue Exception => e
  handle_error(e)
end
```

## Anti-Patterns

### VRE Veteran Claim
**Anti-pattern:**
```ruby
def veteran_va_file_number(user)
  response = ::BGS::People::Request.new.find_person_by_participant_id(user:)
  response.file_number
rescue  # Bare rescue catches ALL exceptions
  Rails.logger.warn('VRE claim unable to add VA File Number.', { user_uuid: user&.uuid })
  nil  # Returns nil for ALL failures
end
```
**Problem:** Bare `rescue` catches `NoMethodError` from typos, `SystemExit`, and `SignalException`. Returns nil for every failure -- a BGS timeout is indistinguishable from "no file number." APM never sees the error.

**Corrected:**
```ruby
def veteran_va_file_number(user)
  response = ::BGS::People::Request.new.find_person_by_participant_id(user:)
  response.file_number
rescue BGS::ServiceError, Faraday::Error => e
  Rails.logger.warn('BGS unavailable', { user_uuid: user&.uuid, error: e.class })
  raise Common::Exceptions::ServiceUnavailable.new(cause: e)
end
```

### Cemeteries Controller
**Anti-pattern:**
```ruby
def index
  cemeteries = SimpleFormsApi::CemeteryService.all
  render json: { data: cemeteries.map { |cemetery| format_cemetery(cemetery) } }
rescue => e  # Same as bare rescue -- catches EVERYTHING
  Rails.logger.error "Cemetery controller error: #{e.message}"
  Rails.logger.error e.backtrace.join("\n")
  render json: { error: 'Unable to load cemetery data' }, status: :internal_server_error
end
```
**Problem:** `rescue => e` catches all `StandardError` subclasses. Manual backtrace logging duplicates APM. A typo in `format_cemetery` returns the same generic 500 as a network timeout -- no diagnostic precision.

**Corrected:**
```ruby
def index
  cemeteries = SimpleFormsApi::CemeteryService.all
  render json: { data: cemeteries.map { |cemetery| format_cemetery(cemetery) } }
rescue SimpleFormsApi::ServiceError, Faraday::Error => e
  render_api_exception(e)
end
# NoMethodError raises to APM -- code bugs visible
```

### SAML User
**Anti-pattern:**
```ruby
def authn_context
  saml_response.authn_context_text
rescue  # Bare rescue catches everything just to set Sentry tags
  Sentry.set_tags(controller_name: 'sessions', sign_in_method: 'not-signed-in:error')
  raise  # Re-raises after catching -- tags ALL exceptions including bugs
end
```
**Problem:** Bare rescue catches and tags all exceptions -- a `NoMethodError` gets tagged as "not-signed-in:error," which is misleading. Sentry dashboards cannot distinguish SAML errors from code bugs.

**Corrected:**
```ruby
def authn_context
  saml_response.authn_context_text
rescue SAML::ValidationError, SAML::MissingAttributeError => e
  Sentry.set_tags(controller_name: 'sessions', sign_in_method: 'not-signed-in:saml-error')
  raise
end
# Unexpected errors raise without misleading tags
```

## Finding Template
**Never Use Broad or Bare Rescues** | `CRITICAL`

`{{file_path}}:{{line_number}}` -- `{{rescue_pattern}}` catches all exceptions
including `NoMethodError` from typos. APM cannot see errors caught this way.

**Why this matters:** All failures return the same result. On-call can't
distinguish service outage from code bug. BGS timeout looks like "no file number."

**Suggested fix:**
```ruby
{{suggested_code}}
```

- [ ] Rescue specifies exception class(es)
- [ ] No nil/false return for failures
- [ ] Cause chain preserved with `cause: e`

[Play: Never Use Broad or Bare Rescues](plays/never-use-bare-rescues.md)

## Verify Commands
- `grep -On '^\s*rescue\s*$' {{file_path}}` -- No bare rescue remains
- `grep -On '^\s*rescue\s*=>' {{file_path}}` -- No rescue => e without class
- `grep -On 'rescue\s+Exception\b' {{file_path}}` -- No rescue Exception

## Related Plays
- dont-swallow-errors (complementary)
- preserve-cause-chains (complementary)
- classify-errors (complementary)
- dont-catch-log-reraise (complementary)
