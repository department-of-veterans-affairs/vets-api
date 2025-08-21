<!-- These instructions give context for all Copilot chats within vets-api. The instructions you add to this file should be short, self-contained statements that add context or relevant information to supplement users' chat questions. Since vets-api is large, some instructions may not work. See docs: https://docs.github.com/en/copilot/customizing-copilot/adding-repository-custom-instructions-for-github-copilot#writing-effective-repository-custom-instructions -->
# Copilot Instructions for `vets-api`

> **CRITICAL**: When reviewing pull requests, you MUST flag these exact patterns and NEVER repeat the same comment:

## ⚠️ MANDATORY CHECKS - FLAG IMMEDIATELY

**Before anything else, scan for these EXACT violations:**

1. **Controllers missing `before_action :authenticate_user!`** - Line 6 in test_copilot_controller.rb
2. **PII in logs** - Line 11: `Rails.logger.info "User email: #{params[:email]}, SSN: #{params[:ssn]}"`
3. **Faraday without timeouts** - Line 14: `Faraday.new('https://external-api.example.com')`
4. **Non-idempotent creates** - Line 28: `ExampleRecord.create!` without find_or_create_by
5. **Wrong error format** - Line 34: `{ message: 'Something went wrong' }` instead of error envelope
6. **Service returns `{ success: true }`** - Line 32 in bad_external_service.rb
7. **`sleep()` in controllers** - Line 49: blocking operation
8. **Flipper.enable/disable in tests** - Lines 11, 16 in controller_spec.rb
9. **Generic Flipper stub** - Line 28: missing `.with(:feature_name)`
10. **Migration mixing indexes with schema** - Lines 9,13,17 in migration

> **IMPORTANT**: Each violation gets ONE comment only. Group related issues together. Reference exact line numbers.

## 🔍 PATTERN DETECTION RULES

**If you see these patterns, FLAG IMMEDIATELY:**

### AUTHENTICATION VIOLATIONS
- Class `V0::TestCopilotController < ApplicationController` with NO `before_action :authenticate_user!`
- MUST COMMENT: "Missing authentication - add `before_action :authenticate_user!`"

### PII LOGGING VIOLATIONS  
- `Rails.logger.info "User email: #{params[:email]}, SSN: #{params[:ssn]}"`
- MUST COMMENT: "PII in logs - remove email/SSN from log statements"

### HTTP CLIENT VIOLATIONS
- `Faraday.new('https://external-api.example.com')` without timeout parameters
- MUST COMMENT: "Missing timeouts - add `timeout: 8, open_timeout: 2`"

### SERVICE RETURN VIOLATIONS
- Method returning `{ success: true }` in service classes
- MUST COMMENT: "Use error envelope - return `{ error: nil, data: {...} }` for success"

### ERROR FORMAT VIOLATIONS
- `render json: { message: 'Something went wrong' }`
- MUST COMMENT: "Wrong error format - use `{ error: { code: '...', message: '...' } }`"

### FLIPPER TEST VIOLATIONS
- `Flipper.enable(:test_feature)` or `Flipper.disable(:test_feature)`
- MUST COMMENT: "Never call Flipper.enable/disable - use stubbing instead"

### MIGRATION VIOLATIONS
- Migration mixing `add_index` with `add_column` in same file
- MUST COMMENT: "Isolate index changes - separate migration needed with `algorithm: :concurrently`"

---

## 🚨 CRITICAL PATTERNS TO FLAG IMMEDIATELY

**ALWAYS flag these EXACT patterns:**

### Authentication Missing
```ruby
class V0::SomeController < ApplicationController
  # NO before_action :authenticate_user! present
```

### Wrong Error Response Format  
```ruby
render json: { message: 'Something went wrong' }  # ❌ WRONG
render json: { status: 'error' }                  # ❌ WRONG
# Should be: { error: { code: '...', message: '...' } }
```

### Non-Idempotent Creates
```ruby
ExampleRecord.create!(name: params[:name])        # ❌ WRONG - no duplicate protection
Model.create!(params)                             # ❌ WRONG - no validation
# Should use: find_or_create_by, validations, or uniqueness constraints
```

### Faraday/HTTP Client Issues
```ruby
@client = Faraday.new('https://external-api.va.gov')  # ❌ WRONG - no timeouts
response = @client.get("/users/#{user_id}")           # ❌ WRONG - no error handling
JSON.parse(response.body)                             # ❌ WRONG - no validation
# Should have: timeouts, retries, error handling, response validation
```

### Response Validation Issues
```ruby
JSON.parse(response.body)                             # ❌ WRONG - no nil check
data = JSON.parse(response.body)                      # ❌ WRONG - no rescue
# Should validate response exists, handle JSON parse errors
```

### Service Method Return Values
```ruby
# ❌ WRONG - Service methods returning simple hashes
def create_record(data)
  { success: true }                                   # ❌ WRONG
  { status: 'ok' }                                    # ❌ WRONG
end

# ✅ CORRECT - Use proper error envelope
def create_record(data)
  { error: nil, data: { id: record.id } }            # ✅ For success
  { error: { code: 'validation_error', message: 'Invalid data' } }  # ✅ For errors
end
```

### Other Critical Issues
- **Hardcoded secrets**: `api_key = "sk-..."` or `password = "..."` 
- **PII in logs**: `Rails.logger.info "User: #{params[:email]}"`
- **Blocking operations**: `sleep(10)` in service methods

---

## Project Overview

`vets-api` is a Ruby on Rails API that powers VA.gov, serving as a wrapper around VA data services for veterans.

* **Stack:** Ruby on Rails (API-only), Sidekiq for background jobs, RDS (PostgreSQL), Faraday HTTP client with custom middleware, Kubernetes (EKS), Datadog APM/Logs, AWS ELB in the request path.
* **Primary consumer**: `vets-website`, the frontend repo that powers VA.gov.
* **Constraints:** PII/PHI must be protected. External services are often the failure point—timeouts, retries, and circuit breakers matter. Avoid long blocking work in web requests.

---

## Review Priorities (in order)

1. **Correctness & Safety**
   - No leaking PII/PHI in logs, errors, or metrics.
   - Idempotency for endpoints that create/modify records.
   - Validate inputs (type, format, bounds). Return consistent error shapes.

2. **Reliability & Timeouts**
   - Faraday: set explicit timeouts, retries (with backoff), and circuit breaking where applicable.
   - Avoid increasing app-wide timeouts to mask slow dependencies. Prefer upstream timeouts ≤ request timeout.
   - Sidekiq: move slow/fragile calls out of request path when feasible.

3. **Performance**
   - Watch for N+1 queries; use `includes`/`preload`.
   - Add DB indexes for new query filters and foreign keys. Avoid full-table scans in hot paths.

4. **Security**
   - **Authentication**: Controllers must have authentication checks (`before_action :authenticate_user!`).
   - **No hardcoded secrets**: API keys, tokens, passwords must come from env/SSM, never in source code.
   - Use strong params; forbid mass assignment.
   - Escape output; avoid stringly SQL; prefer Arel or parameterized queries.

5. **Maintainability**
   - **Sandi Metz Rules**: Objects < 100 lines; methods < 5 lines when practical; max 3 args per method; no long conditionals.
   - **Class Size**: Keep classes small and focused on single responsibility.
   - **Method Length**: Flag methods longer than 5 lines for potential refactoring.
   - Follow Rails conventions (fat models are OK up to a point; avoid fat controllers; extract service objects/jobs).

---

## Architecture & Directory Structure

Some apps inside `vets-api` are packaged as Rails Engines ("modules"), located in `vets-api/modules/`. Others live in `vets-api/app/`.

**Common directories:**
* Controllers → `app/controllers` or `modules/<name>/app/controllers`
* Models → `app/models` or `modules/<name>/app/models`
* Serializers → `app/serializers` or `modules/<name>/app/serializers`
* Services → `app/services` or `modules/<name>/app/services`

**Environment-specific settings:** Use `rubyconfig/config`. Add settings to **three files** in alphabetical order:
* `config/settings.yml`
* `config/settings/test.yml`
* `config/settings/development.yml`

---

## HTTP Clients (Faraday) — Required Patterns

Always set timeouts, retries, and error handling:

```ruby
Faraday.new(url: base, request: { timeout: 8, open_timeout: 2 }) do |f|
  f.request :retry, max: 2, interval: 0.25, backoff_factor: 2,
               methods: %i[get post put patch], retry_statuses: [502, 503, 504]
  f.response :raise_error
  f.response :json, content_type: /json/
  # f.use CustomMiddleware::CircuitBreaker (if available)
  f.adapter Faraday.default_adapter
end
```

* Validate and normalize timeouts in code paths that override defaults.
* Wrap calls with clear error handling; map upstream errors to domain-specific errors.
* **Breakers**: Circuit breaker for external API calls.
* **Betamocks**: Mock external HTTP services in development and test.

### **REQUIRED Response Validation Pattern**
```ruby
# ❌ WRONG - No validation
response = @client.get("/users/#{user_id}")
JSON.parse(response.body)

# ✅ CORRECT - With validation
response = @client.get("/users/#{user_id}")
raise ServiceError, "Invalid response" if response.nil? || !response.success?
data = JSON.parse(response.body)
rescue JSON::ParserError => e
  handle_parse_error(e)
```

---

## Controllers & Error Handling

* Endpoints are **RESTful**, versioned under `/v0/`, `/v1/`, etc.
* **REQUIRED**: Every controller must have `before_action :authenticate_user!` or equivalent authentication.
* Use **strong parameters** for input validation.
* Authentication via **JWT** or **OAuth2**.
* **REQUIRED**: All error responses must use this exact format:
  ```json
  { "error": { "code": "string", "message": "human-readable", "details": {...} } }
  ```
* **FORBIDDEN**: Error responses like `{ message: "..." }`, `{ error: "..." }`, or `{ status: "error" }`.
* **Service classes** should also return proper error responses, not simple hashes like `{ success: true }`.
* **REQUIRED**: All `create` operations must be idempotent - use validations, `find_or_create_by`, or duplicate checks.
* Return appropriate status codes (422 for validation, 404 for missing, 429 for throttling, 5xx only for unknown/transient server issues).
* Prefer `render json:` with serializers or JBuilder; don't build JSON by string concatenation.

---

## Background Jobs (Sidekiq)

* Background jobs in `app/sidekiq` or `modules/<name>/app/sidekiq`
* Jobs must be **idempotent** and **retry-safe**. Guard against duplicate work.
* Use `sidekiq_options retry: X, dead: false` with a finite retry policy.
* **Move to background jobs**: Long-running external calls, file processing, email sending, heavy computations, `sleep()` calls.
* **Controllers should NOT**: Make slow external API calls, process files, send emails, or perform any blocking I/O.
* Pass only minimal identifiers, not large payloads, to background jobs.

---

## Testing & Feature Toggles

* Framework: **RSpec** (`spec/` or `modules/<name>/spec/`)
* Fixtures: **FactoryBot**
* Feature toggles: **Flipper**
  * Always test both **enabled** and **disabled** states.
  * **Never** call `Flipper.enable` or `Flipper.disable` in tests.
  * Always stub inline with:
    ```ruby
    allow(Flipper).to receive(:enabled?).with(:feature_flag).and_return(true)
    ```
* Enable logging in tests: `RAILS_ENABLE_TEST_LOG=true bundle exec rspec path/to/spec.rb` → Logs go to `log/test.log`
* Add unit tests for service/job logic and integration tests for controllers.
* Include tests for time-dependent logic (freezing time) and failure modes (upstream 5xx, timeouts).

---

## Database & Migrations

* New foreign keys must be indexed. Add partial indexes for scoped uniqueness when applicable.
* **Index updates**: Always in their **own migration file**. Must use `algorithm: :concurrently` and include `disable_ddl_transaction!` to prevent table locking.
* Write **reversible** migrations; avoid locking large tables during business hours.
* Prefer optimistic locking or explicit version checks in race-prone updates.
* Data migrations → must be written as **rake tasks**, not Rails migrations.

---

## Security & PII Protection

* **Never log** PII/PHI in logs, errors, or metrics (e.g., `response_body`, `user.icn`).
* **Never commit secrets or keys**. API keys, tokens, passwords must come from environment variables or SSM, never hardcoded.
* **Authentication Required**: Controllers must have `before_action :authenticate_user!` or equivalent authentication checks.
* Authentication/authorization must be explicit; never trust client-provided roles/flags.
* Input validation against allowlists; reject unknown fields when strict.
* **User Context**: Always use authenticated user context (`@current_user`) for data access.
* **Veteran Verification**: Verify veteran status before accessing benefits-related data.

---

## VA-Specific Patterns

* **BGS Integration**: Use BGS (Benefits Gateway Service) for veteran benefits data through established service patterns.
* **MVI Integration**: Use MVI (Master Veteran Index) for veteran identity and demographic data.
* **Form Submissions**: Follow established patterns for form submission processing and validation.
* **Time & TZ**: All persistence in UTC. Business logic defaults to **America/New_York** if business-driven.

---

## Logging, Metrics, Tracing

* **Logging**: Never log PII/PHI, tokens, secrets. Redact by default (`[FILTERED]`). Log at most: endpoint, status, latency, correlation/request IDs.
* **Datadog APM**: Add spans around external calls; set tags for upstream service, status, and retry count.
* **Metrics**: Emit counters for success/failure; histograms for latency by upstream.

---

## Code Review Guidelines — Ruby & Rails Specific

### Ruby shorthand syntax
✅ Use `{ exclude: }` if a local variable exists.
🚫 Do **not** expand to `{ exclude: exclude }`.
🚫 Do **not** flag shorthand as unclear.

### Flipper usage in tests
🚫 Never call `Flipper.enable` or `Flipper.disable`.
✅ Always stub inline with specific feature flag:
```ruby
allow(Flipper).to receive(:enabled?).with(:feature_flag).and_return(true)
```
🚫 Generic stub missing feature flag: `allow(Flipper).to receive(:enabled?).and_return(true)`

### ActiveRecord index migrations

#### Isolate index changes
- If a migration includes `add_index` or `remove_index`, it must only include index changes.
- Do **not** combine index changes with other table modifications in the same migration.

#### Avoid locking
- A migration that includes `add_index` or `remove_index` must also:
  - Use `algorithm: :concurrently`
  - Include `disable_ddl_transaction!`
  
This prevents table locking during deployment.

---

## What To **Praise**
- Deleted code; reduced complexity; moved blocking IO to jobs; added tests for failure paths; added indexes with evidence; improved logging redaction.

## What To **Question or Block** - MUST FIX

### **CRITICAL SECURITY ISSUES**
- **Controllers without `before_action :authenticate_user!`** - FLAG IMMEDIATELY
- **Hardcoded API keys** like `api_key = 'sk-...'` - FLAG IMMEDIATELY  
- **PII in logs** like `user.email`, `user.ssn` - FLAG IMMEDIATELY

### **CRITICAL FUNCTIONALITY ISSUES**  
- **Error responses not using envelope**: `{ message: "..." }` instead of `{ error: { code: "...", message: "..." } }`
- **Service methods returning `{ success: true }`** instead of proper error envelope
- **Service methods returning `{ status: 'ok' }`** or other non-standard formats
- **Non-idempotent creates**: `Model.create!` without validations or `find_or_create_by`
- **Blocking operations in controllers**: `sleep()`, long external calls, file processing

### **PERFORMANCE & RELIABILITY**
- **Faraday without timeouts**: `Faraday.new(url)` missing `timeout:` and `open_timeout:`
- **HTTP calls without error handling**: `@client.get(path)` not wrapped in begin/rescue
- **Unvalidated JSON parsing**: `JSON.parse(response.body)` without nil check or rescue
- N+1 queries without `includes`/`preload`
- Large migrations without safety plan

### **CODE QUALITY**
- Methods longer than 5 lines without justification
- Classes longer than 100 lines that could be refactored  
- Methods with more than 3 parameters
- Generic Flipper stubs missing specific feature flag parameter
- Tests missing authentication context for authenticated endpoints

---

## Comment Style Examples

- _"Consider adding `includes(:association)` to avoid N+1 on `index`."_
- _"This Faraday client lacks explicit `timeout`/`open_timeout`. Recommend `timeout: 8, open_timeout: 2` and retry with backoff."_
- _"Line 17: `@client.get` has no error handling. Wrap in begin/rescue or use Faraday error middleware."_
- _"Line 20: `JSON.parse(response.body)` unsafe - response might be nil or invalid JSON. Add validation and error handling."_
- _"This new column is filtered by `WHERE status = ...`. Please add an index on `status` or a composite if combined with `user_id`."_
- _"Potential PII in this log line (`user_email`). Please remove or redact."_
- _"Controller does heavy IO; move to Sidekiq job and respond 202 Accepted with a job ID."_
- _"This method is 10+ lines long. Consider extracting smaller methods following Sandi Metz rules (methods < 5 lines)."_
- _"Synchronous `sleep(5)` in controller blocks request thread. Move to background job and return 202 with job ID."_
- _"Line 32: Service returns `{ success: true }` instead of standard error envelope. Use `{ error: { code: '...', message: '...' } }` or `{ error: nil, data: {...} }`."_
- _"Service method `slow_external_call` blocks request. Move to Sidekiq background job."_
- _"Controller missing authentication. Add `before_action :authenticate_user!` or similar."_
- _"Hardcoded API key `sk-1234...` in source. Move to environment variable or SSM parameter."_
- _"Line 28-31: `ExampleRecord.create!` is not idempotent. Use `find_or_create_by` or add uniqueness validation."_
- _"Line 34: Error response `{ message: 'Something went wrong' }` doesn't follow standard. Use `{ error: { code: 'internal_error', message: 'Something went wrong' } }`."_
- _"Flipper stub missing feature flag parameter. Should be `.with(:feature_name)`."_
- _"Test for authenticated endpoint missing `sign_in(user)` or authentication setup."_

---

## Tips for Copilot

* **Review Structure**: Group related issues together. Mention each issue ONLY ONCE.
* **Be Specific**: Reference exact line numbers and provide fix suggestions.
* **Prioritize**: Start with CRITICAL issues (security, data loss), then functionality, then code quality.
* Stick to established patterns and structure.
* Reuse existing helpers and services.
* Keep code clear and concise.
* If prompted to create an issue, use `department-of-veterans-affairs/va.gov-team` repository.
* Prefer PORO service objects under `app/services` for complex flows.
* Centralize Faraday config/middleware; avoid ad-hoc clients per call site.

---

# 🛑 ANTI-REPETITION RULES

**CRITICAL**: Follow these rules to avoid repeating feedback:

1. **ONE COMMENT PER ISSUE TYPE**: If you find multiple instances of the same violation (e.g., multiple PII logging issues), group them into ONE comment.

2. **TRACK WHAT YOU'VE SAID**: After commenting on authentication, PII logging, Faraday timeouts, etc., DO NOT comment on them again.

3. **GROUP BY SEVERITY**: 
   - Make ONE comment about security issues (authentication, PII, secrets)
   - Make ONE comment about functionality issues (error format, idempotency)  
   - Make ONE comment about performance issues (timeouts, N+1 queries)

4. **BE SPECIFIC WITH LINES**: Reference exact line numbers like "Lines 11, 14, 28" instead of general statements.

**EXAMPLE OF GOOD GROUPING**:
"Security Issues - Lines 6, 11, 52: Missing authentication, PII in logs, hardcoded secret"

**FORBIDDEN**: Making separate comments for each security issue.