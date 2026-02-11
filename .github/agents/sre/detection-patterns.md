# Detection Patterns by Play

Read this file as the first step of every audit. Use these patterns with `search` (grep) to find potential violations, then read surrounding context before flagging.

**Pattern confidence levels:**
- `[HIGH]` — Always flag if pattern matches (outside test files)
- `[MEDIUM]` — Read 10-20 lines of context before flagging; apply false-positive heuristics

**General exclusions:** Skip `spec/`, `test/`, and `fixtures/` directories unless a play specifically notes otherwise.

---

## P1 CRITICAL PLAYS (Tier 1+)

### Play 01: Don't Leak PII/PHI/Secrets
File: `plays/01-dont-leak-pii-phi-secrets.md`
Patterns:
  - [HIGH] response_body_in_raise: `raise\s+".*resp\.body`
  - [HIGH] response_body_keyword_in_raise: `raise\s+".*response.*body`
  - [MEDIUM] logger_with_response_body: `logger\.\w+.*\.body`
  - [MEDIUM] params_in_meta: `meta:.*params`
Rules:
  - MUST NOT: Never include PII (names, emails, SSNs), PHI (medical info), or secrets (API keys, tokens) in error messages or logs
  - MUST: Use safe identifiers (UUIDs, internal IDs, case IDs) for debugging context
  - MUST: Scrub sensitive data from stack traces and exception messages before they reach logging infrastructure
  - MUST: Use allowlists for meta fields in structured logs — never blindly include user data or response bodies
False positives:
  - Logging `resp.body` for internal health-check endpoints returning only static non-sensitive data
  - `resp.body` in test/spec code using fixture data

### Play 02: Preserve Cause Chains
File: `plays/02-preserve-cause-chains.md`
Patterns:
  - [MEDIUM] raise_new_exception_without_cause: `raise\s+\w+Exception\.new\([^)]*\)\s*$`
  - [HIGH] stringified_reraise: `raise\s+".*#\{.*\}"`
  - [HIGH] wrap_with_message_only: `raise\s+\w+\.new\(.*\.message\)`
Rules:
  - MUST: When catching an exception to add context, always wrap it with `cause: e`
  - MUST NOT: Never use `raise "error: #{e}"` — destroys original exception class, backtrace, and cause chain
  - MUST NOT: Never catch and re-raise without setting `cause:` — original stack trace will be lost
  - SHOULD: If not adding context when re-raising, use bare `raise` to preserve automatically
False positives:
  - Bare `raise` (re-raise without arguments) inside a rescue block is correct — Ruby preserves the original exception
  - Exception constructors that accept the original exception as a positional argument and internally set the cause chain — verify by reading the exception class definition
  - Raising a new exception in code NOT inside a rescue block — no caught exception to preserve

### Play 03: Never Use Bare Rescues
File: `plays/03-never-use-bare-rescues.md`
Patterns:
  - [HIGH] bare_rescue_no_class: `rescue\s*$`
  - [HIGH] rescue_hashrocket_no_class: `rescue\s*=>\s*\w+`
  - [HIGH] rescue_exception_class: `rescue\s+Exception\b`
  - [MEDIUM] rescue_nil_return: `rescue.*\n\s*(nil|false|\[\]|\{\})\s*$`
Rules:
  - MUST: Always specify exception classes in rescue blocks
  - MUST NOT: Never use bare `rescue` or `rescue => e` without a class
  - MUST NOT: Never catch `Exception` (catches system signals, SystemExit)
  - SHOULD: Use `rescue StandardError` only at controller/job boundaries
False positives:
  - `rescue StandardError => e` at a controller action boundary or Sidekiq `perform` method is acceptable as the outermost handler
  - `rescue => e` in test/spec files is acceptable for testing error paths

### Play 04: Map Upstream Network Errors
File: `plays/04-map-upstream-network-errors-correctly.md`
Patterns:
  - [HIGH] faraday_error_to_internal_server_error: `rescue\s+Faraday::\w+.*\n.*InternalServerError`
  - [MEDIUM] faraday_blanket_catch: `rescue\s+Faraday::ClientError,\s*Faraday::ServerError`
  - [HIGH] upstream_to_500_with_exception: `raise.*InternalServerError.*exception:\s*e`
Rules:
  - MUST: Map connection/DNS failures to 503, timeouts to 504, upstream server errors to 502
  - MUST NOT: Never map upstream network errors to 500 — 500 means our code is broken
  - MUST NOT: Never catch all Faraday errors with a single rescue clause returning one status code
  - SHOULD: Include `meta.upstream_status` when wrapping upstream server errors as 502
False positives:
  - Catching `Faraday::ClientError` (4xx from upstream) and mapping to a specific client error (404/422) is acceptable
  - Generic Faraday rescue inside a retry wrapper that re-raises after exhausting retries

### Play 05: Classify Errors Honestly
File: `plays/05-classify-errors-honestly.md`
Patterns:
  - [HIGH] bare_rescue_returning_422: `rescue\s*=>\s*e.*\n.*raise.*UnprocessableEntity`
  - [MEDIUM] catch_all_then_422: `rescue.*\n.*raise.*422`
  - [MEDIUM] broad_rescue_to_unprocessable_entity: `rescue\s+.*Error.*\n.*raise.*UnprocessableEntity`
Rules:
  - MUST: Choose HTTP status by ownership: 4xx when client must change request, 5xx when our code or upstream is at fault
  - MUST NOT: Never rebrand 5xx as 4xx to quiet dashboards
  - MUST: Catch only specific validation exceptions before returning 422
  - SHOULD: Ask "Who fixes this?" before choosing a status code family
False positives:
  - Catching only specific validation exception classes (e.g., `rescue ValidationError, ArgumentError`) and raising 422 is correct
  - `rescue ActiveRecord::RecordInvalid` returning 422 is acceptable — validation failures on client-provided data

### Play 06: Handle 401 Token Ownership
File: `plays/06-handle-401-token-ownership.md`
Patterns:
  - [HIGH] blind_401_passthrough: `rescue\s+.*UnauthorizedError.*\n.*raise.*Unauthorized`
  - [MEDIUM] upstream_auth_raise: `raise.*Unauthorized.*upstream.*auth`
  - [HIGH] faraday_unauthorized_no_service_check: `rescue\s+Faraday::UnauthorizedError`
Rules:
  - MUST: Ask "Whose credentials failed?" before choosing status for upstream 401 errors
  - MUST: Return 500 (not 401) when our service account credentials fail upstream
  - MUST NOT: Never pass through all upstream 401 errors blindly as 401 to clients
  - SHOULD: Include actionable detail messages for user tokens vs service accounts
False positives:
  - Rescue for Faraday::UnauthorizedError that explicitly checks whether request used user-provided credentials
  - Controllers handling direct user login (sessions, sign-in) where only user credentials are involved

### Play 07: Handle 403 Permission vs Existence
File: `plays/07-handle-403-permission-vs-existence.md`
Patterns:
  - [HIGH] forbidden_with_record_not_found: `raise.*Forbidden.*\n.*RecordNotFound|RecordNotFound.*\n.*Forbidden`
  - [MEDIUM] forbidden_access_denied: `Forbidden\.new.*detail.*access denied`
  - [HIGH] rescue_not_found_raises_forbidden: `rescue\s+ActiveRecord::RecordNotFound.*\n.*Forbidden`
Rules:
  - MUST: Use 403 only for authenticated users who lack permission
  - MUST NOT: Never return 403 for expired/missing tokens (use 401)
  - MUST NOT: Never return 403 for non-existent resources (use 404)
  - MUST: Return 404 instead of 403 when resource existence should be hidden to prevent enumeration attacks
False positives:
  - 403 for resources where existence is already public knowledge
  - Authorization middleware/before_action filters for role-based endpoint access (not individual resource IDs)

### Play 08: Prefer Typed Exceptions
File: `plays/08-prefer-typed-exceptions.md`
Patterns:
  - [HIGH] untyped_string_raise: `raise\s+['"][^'"]+['"]`
  - [HIGH] untyped_raise_required: `raise\s+['"].*required`
  - [HIGH] untyped_raise_missing: `raise\s+['"].*missing`
Rules:
  - MUST: Use typed exception classes instead of `raise 'string'` in all HTTP request paths
  - MUST: Choose exception classes that map to correct HTTP status codes
  - MUST NOT: Never use `raise 'message'` for client errors — these become indistinguishable 500s
  - SHOULD: Create domain-specific exception hierarchies for multiple failure modes
False positives:
  - `raise 'string'` in rake tasks or CLI scripts not in HTTP request paths
  - `raise 'string'` in test/spec files
  - `raise SomeTypedException, 'message'` — string is the message argument, not the exception type

### Play 09: Expected vs Unexpected Errors
File: `plays/09-expected-vs-unexpected-errors.md`
Patterns:
  - [HIGH] set_error_without_status_check: `set_error\(`
  - [HIGH] span_set_error_in_controller: `span\.set_error`
  - [MEDIUM] span_set_tag_error_in_rescue: `span\.set_tag.*error`
Rules:
  - MUST: Log expected errors (4xx) as WARN, do NOT call span.set_error
  - MUST: Log unexpected errors (5xx) as ERROR and call span.set_error
  - MUST: ExceptionHandling must check status >= 500 before calling span.set_error
  - MUST NOT: Never call span.set_error for 4xx exceptions
  - MUST NOT: Never manually tag spans with error metadata in controllers
False positives:
  - `span.set_error` inside a conditional checking `status_code >= 500` is correct (the golden pattern)
  - `span.set_tag` for non-error metadata (e.g., `span.set_tag('service.name', ...)`)

### Play 10: Don't Build Module-Specific Frameworks
File: `plays/10-dont-build-module-specific-frameworks.md`
Patterns:
  - [HIGH] custom_log_service_class: `class\s+\w*LogService`
  - [MEDIUM] custom_monitor_class: `class\s+\w*Monitor\b`
  - [HIGH] custom_error_handler_class: `class\s+\w*ErrorHandler`
  - [HIGH] custom_rescue_from_in_module: `def\s+rescue_from`
Rules:
  - MUST NOT: Do NOT create module-specific error handlers, logging services, monitoring classes, or tracing wrappers
  - MUST: Use ExceptionHandling concern for error handling — let exceptions bubble up
  - MUST NOT: Never wrap Datadog::Tracing, Rails.logger, or StatsD in module-specific custom classes
  - MUST NOT: Never build module-specific rescue_from handlers
  - SHOULD: Use standard Rails/Datadog APIs directly
False positives:
  - Faraday middleware for HTTP client logging (e.g., `vaos/middleware/vaos_logging.rb`)
  - Domain-specific exception classes (e.g., `ClaimsApi::PowerOfAttorneyNotFound`)
  - Module-specific business logic that includes logging for domain purposes (e.g., JWT jti extraction for audit)

### Play 11: Standardized Error Responses
File: `plays/11-standardized-error-responses.md`
Patterns:
  - [HIGH] manual_error_rendering: `render\s+json:.*\berror\b:`
  - [HIGH] render_error_without_status: `render\s+json:.*\berror\b.*(?!status)`
  - [HIGH] custom_error_renderer_method: `def\s+render_error`
  - [MEDIUM] success_false_field: `success:\s*false`
Rules:
  - MUST NOT: Never manually render error responses in controllers — no `render json: { error: ... }`
  - MUST: Always raise typed exceptions from `Common::Exceptions` and let ExceptionHandling render
  - MUST: Always use `errors` array (not singular `error` key) following JSON:API spec
  - MUST NOT: Never define custom `render_error` methods in controllers
  - MUST NOT: Never use custom fields like `success: false`
False positives:
  - `render json: { error: ... }` in test helpers or spec support files
  - `render json: { errors: ... }` inside ExceptionHandling concern itself

---

## P2 IMPORTANT PLAYS (Tier 2+)

### Play 12: Never Return 2xx with Errors
File: `plays/12-never-return-2xx-with-errors.md`
Patterns:
  - [HIGH] render_error_without_status: `render\s+json:.*error.*(?!status)`
  - [MEDIUM] custom_success_false_field: `success:\s*false`
  - [HIGH] render_error_no_status_multiline: `render\s+json:.*\berror\b.*$`
Rules:
  - MUST: Every `render json:` in an error path MUST include an explicit `status:` parameter
  - MUST NOT: Never return 2xx when response body contains an error
  - MUST NOT: Never use custom `success: false` fields
False positives:
  - `render json: { error: ... }, status: :not_found` — status parameter present and correct
  - `render json: { data: results, meta: { errors: warnings } }, status: :ok` — non-fatal warnings in successful response

### Play 13: Send Retry Hints
File: `plays/13-send-retry-hints-to-clients.md`
Patterns:
  - [HIGH] 429_response_missing_retry_after: `\[429,.*headers`
  - [HIGH] 429_converted_to_503: `raise.*ServiceUnavailable.*TooManyRequests`
  - [MEDIUM] handle_429_without_retry_after: `handle_429`
Rules:
  - MUST: Include Retry-After header with 429 Too Many Requests responses
  - MUST NOT: Never send Retry-After for permanent failures (404, 410, 403)
  - MUST NOT: Never convert 429 to 503 — preserve rate limit semantics
  - SHOULD: Propagate upstream Retry-After timing through exception metadata
False positives:
  - 429 response that already includes Retry-After header
  - handle_429 method that extracts and propagates Retry-After from upstream headers

### Play 14: Don't Mix Error Concerns
File: `plays/14-dont-mix-error-concerns.md`
Patterns:
  - [HIGH] controller_catches_http_client: `rescue\s+Faraday::` (only in controller files)
  - [MEDIUM] response_error_field_check: `\.error\.present\?`
  - [HIGH] http_like_response_with_error: `status:\s*200.*error:`
Rules:
  - MUST: Service layer must wrap infrastructure exceptions into domain-typed exceptions before controllers
  - MUST: Controllers must catch only domain exceptions, never infrastructure library classes
  - MUST: Service methods must return data on success and raise on failure — not return error objects
  - MUST NOT: Domain layer must not render responses
False positives:
  - `rescue Faraday::Error` inside a service layer file (not a controller) — services SHOULD catch infrastructure exceptions
  - `.error.present?` on ActiveModel objects checking validation errors
  - Response objects from external APIs (parsed JSON with status and error fields)

### Play 15: Stable Unique Error Codes
File: `plays/15-stable-unique-error-codes.md`
Patterns:
  - [HIGH] duplicate_code_values_in_yaml: `code:\s*(\d+)` (check for duplicates across exceptions.en.yml)
  - [MEDIUM] http_status_as_error_code: `code:\s*\d{3}\s*$` (where code matches status on nearby line)
  - [MEDIUM] non_namespaced_numeric_code: `code:\s*\d+\s*$`
Rules:
  - MUST: Error codes must be unique across the system — no two distinct conditions share the same code
  - MUST: Error codes must be stable — once assigned, never change or reuse
  - MUST NOT: Never use HTTP status code as the error code value
  - SHOULD: Use namespaced string codes for domain specificity (e.g., `CLAIMS_MISSING_SSN`)
False positives:
  - Two exception keys that are aliases for the same condition may intentionally share a code
  - A 3-digit code that is a well-documented unique identifier (not mimicking HTTP status)

### Play 16: Don't Swallow Errors
File: `plays/16-dont-swallow-errors.md`
Patterns:
  - [HIGH] rescue_returning_nil: `rescue.*\n\s*nil\s*$`
  - [HIGH] rescue_returning_false: `rescue.*\n\s*false\s*$`
  - [MEDIUM] rescue_returning_empty_array: `rescue.*\n\s*\[\]\s*$`
  - [MEDIUM] rescue_returning_empty_hash: `rescue.*\n\s*\{\}\s*$`
Rules:
  - MUST NOT: Never return nil or false from a rescue block to hide a failure
  - MUST NOT: Never let retry loops exhaust silently — emit a metric, log once, then raise
  - MUST: Always raise a typed exception when a service call fails
  - SHOULD NOT: Don't catch an exception unless you can handle it meaningfully
False positives:
  - `rescue ActiveRecord::RecordNotFound => e; nil` in a `find_by`-style method where nil means "no record"
  - `rescue Redis::BaseConnectionError => e; default_value` in cache-read helpers with metrics and documented fallback

### Play 17: Prefer Structured Logs
File: `plays/17-prefer-structured-logs.md`
Patterns:
  - [HIGH] string_interpolation_in_log_message: `logger\.\w+\(".*#\{`
  - [HIGH] manual_backtrace_field: `backtrace:\s*e\.backtrace`
  - [MEDIUM] logging_only_exception_message: `logger\.\w+.*\.message`
Rules:
  - MUST: Use Rails Semantic Logger and pass exception object via `exception:` key
  - MUST: Log structured fields alongside exception: event, code, status, service, operation
  - MUST NOT: Never use string interpolation in log messages — pass dynamic values as keyword arguments
  - MUST NOT: Never emit a second log entry with backtrace — Semantic Logger captures it via `exception: e`
  - MUST NOT: Never log request bodies or secrets
False positives:
  - Logger calls interpolating a single static identifier (class name, module constant) with low cardinality
  - Logger calls in test/spec code

### Play 18: Metrics vs Logs Cardinality
File: `plays/18-metrics-vs-logs-cardinality.md`
Patterns:
  - [HIGH] claim_id_in_metric_tags: `StatsD\.\w+.*tags:.*claim_id`
  - [HIGH] user_id_in_metric_tags: `StatsD\.\w+.*tags:.*user_id`
  - [HIGH] params_in_metric_tags: `StatsD\.\w+.*tags:.*params`
  - [HIGH] request_id_in_metric_tags: `StatsD\.\w+.*tags:.*request_id`
Rules:
  - MUST: Use metrics (StatsD) for low-cardinality aggregations only — tags must have < 100 unique values
  - MUST: Use logs for high-cardinality details — claim_id, user_id, request_id belong in log fields
  - MUST NOT: Never tag metrics with claim_id, user_id, request_id, or any unique identifier
  - MUST NOT: Never tag metrics with serialized hashes, JSON strings, or params objects
  - SHOULD: Calculate total cardinality before tagging: card_1 x card_2 x ... x card_n < 10,000 time series
False positives:
  - StatsD calls with tags using known bounded sets (form_type, status, region, environment)
  - StatsD calls where tag values are explicitly whitelisted/bucketed

### Play 19: Validate at Boundaries
File: `plays/19-validate-at-boundaries-fail-fast.md`
Patterns:
  - [HIGH] untyped_raise_missing_param: `raise\s+['"].*missing.*param`
  - [HIGH] untyped_raise_malformed: `raise\s+['"].*malformed`
  - [MEDIUM] late_validation_in_getter: `def\s+get_\w+.*\n.*params\[.*\n.*raise\s+['"]`
Rules:
  - MUST: Validate all inputs at controller boundary before any state change
  - MUST: Use typed exceptions for validation failures (ParameterMissing, UnprocessableEntity)
  - MUST NOT: Never defer parameter validation to helper methods called after state mutation
  - MUST NOT: Never mutate state before validation completes
  - SHOULD: Use Rails strong parameters or before_action callbacks for boundary validation
False positives:
  - Typed exception raises in getter methods called as the very first line of a controller action
  - Validation in `before_action` callbacks (effectively boundary validation)
  - Strong parameters (`params.require(:key)`) raising `ActionController::ParameterMissing` automatically

### Play 20: Don't Catch-Log-Reraise
File: `plays/20-dont-catch-log-reraise.md`
Patterns:
  - [HIGH] catch_log_reraise: `rescue.*\n.*logger\.(error|warn).*\n.*raise\b`
  - [HIGH] manual_backtrace_logging: `\.backtrace\.join`
  - [HIGH] log_message_then_raise: `logger\.(error|warn).*\.message.*\n.*raise\b`
Rules:
  - MUST: Catch only when adding meaningful context or converting to typed exception
  - MUST NOT: Never log and re-raise the same exception — let APM record it once
  - MUST NOT: Never manually log backtraces — APM captures automatically
  - SHOULD: Emit metrics (StatsD counters) for retry attempts, not logs
  - SHOULD: When adding context, wrap with `cause:` and re-raise a new typed exception
False positives:
  - Logging BEFORE wrapping with a new typed exception if the log adds context not in the new exception
  - Emitting StatsD metrics inside rescue before re-raising (metrics are not logs)
  - Logging at different severity to trigger specific alerting rules

### Play 21: Respect Retry Headers
File: `plays/21-respect-retry-headers-when-calling-upstream.md`
Patterns:
  - [HIGH] sidekiq_retry_with_error_logging: `sidekiq_options\s+retry:\s*\d+` (check for logger.error in rescue block)
  - [MEDIUM] bare_rescue_with_retry: `rescue\s*=>\s*e\n.*retry\b`
  - [MEDIUM] sleep_retry_without_exception_filter: `sleep\s+delay.*\n.*retry\b`
Rules:
  - MUST: Only retry transient failures: 429, 503, 504, connection/timeout errors
  - MUST NOT: Never retry client errors (4xx except 429) or code bugs (500)
  - MUST: Respect Retry-After headers from upstream
  - MUST: Fail fast when circuit breaker open or retry budget exhausted
  - MUST NOT: Never log ERROR inside retry loops — log WARN for attempts, ERROR only when exhausted
  - MUST NOT: Never use bare rescue in retry logic — catch specific transient exception classes only
  - MUST: Re-raise when retries exhaust — never silently return nil
False positives:
  - Sidekiq job using `sidekiq_retries_exhausted` for ERROR logging and only WARN in perform rescue
  - Retry helper catching specific exception classes (Faraday::TimeoutError, Faraday::ConnectionFailed)
  - Retry logic in test/spec code

