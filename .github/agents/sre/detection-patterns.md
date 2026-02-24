# Detection Patterns by Play

Read this file as the first step of every audit. For each play, use the **What to look for** description to understand the violation, then use **Grep helpers** (where provided) as starting points for `search`. For patterns that span multiple lines, search for the entry-point line and then `read` surrounding context to confirm.

After finding a match, read the play file for rules, false-positive heuristics, and investigation steps before flagging.

**Confidence levels:**
- `HIGH` — Flag if confirmed after reading context (outside test files)
- `MEDIUM` — Read 10-20 lines of surrounding context; check play file for false positives

**General exclusions:** Skip `spec/`, `test/`, and `fixtures/` directories unless a play specifically notes otherwise.

---

## P1 CRITICAL PLAYS (Tier 1+)

### Play 01: Don't Leak PII/PHI/Secrets
File: [Play 01](.github/agents/sre/plays/01-dont-leak-pii-phi-secrets.md)

**What to look for:** Exception messages or log statements that include raw response bodies, user params, or data that could contain PII/PHI (names, SSNs, medical info) or secrets (API keys, tokens). Common pattern: `raise` or `logger.error` with `.body` or raw `params` interpolated into the message or metadata.

Grep helpers:
- `raise\s+".*resp\.body` — HIGH: raise with response body inline
- `raise\s+".*response.*body` — HIGH: raise referencing response body
- `logger\.\w+.*\.body` — MEDIUM: logger call referencing .body
- `meta:.*params` — MEDIUM: raw params passed as log metadata

### Play 02: Preserve Cause Chains
File: [Play 02](.github/agents/sre/plays/02-preserve-cause-chains.md)

**What to look for:** Rescue blocks that catch an exception and raise a new one without passing `cause: e`. Also: converting an exception to a string with `raise "error: #{e}"` which destroys the original class, backtrace, and cause chain. The fix is `raise NewException.new(message, cause: e)` or bare `raise` to preserve automatically.

Grep helpers:
- `raise\s+".*#\{.*\}"` — HIGH: stringified re-raise destroys cause chain
- `raise\s+\w+\.new\(.*\.message\)` — HIGH: wraps only the message, drops the exception object
- `raise\s+\w+Exception\.new\([^)]*\)\s*$` — MEDIUM: new exception without `cause:` keyword — read context to check if inside a rescue block

### Play 03: Never Use Bare Rescues
File: [Play 03](.github/agents/sre/plays/03-never-use-bare-rescues.md)

**What to look for:** Rescue blocks without an exception class (`rescue`, `rescue => e`, or `rescue Exception`). These catch everything including `NoMethodError` from typos and `SignalException` from Ctrl+C. Also look for rescue blocks that return nil, false, or empty collections — signals of error swallowing combined with bare rescue.

Grep helpers:
- `rescue\s*$` — HIGH: bare rescue on its own line
- `rescue\s*=>\s*\w+` — HIGH: `rescue => e` without exception class
- `rescue\s+Exception\b` — HIGH: catches system signals and exits

Context check (search for `rescue` then read surrounding lines):
- Rescue block followed by `nil`, `false`, `[]`, or `{}` return — MEDIUM

### Play 04: Map Upstream Network Errors
File: [Play 04](.github/agents/sre/plays/04-map-upstream-network-errors-correctly.md)

**What to look for:** Rescue blocks that catch Faraday errors (timeouts, connection failures, upstream 5xx) and map them to `InternalServerError` (500). Upstream failures should map to 502/503/504, not 500 — a 500 means our code is broken. Also look for catching all Faraday errors with a single rescue clause and returning one status code.

Grep helpers:
- `raise.*InternalServerError.*exception:\s*e` — HIGH: wrapping upstream error as 500
- `rescue\s+Faraday::ClientError,\s*Faraday::ServerError` — MEDIUM: blanket catch of all Faraday errors

Context check (search for `rescue\s+Faraday::` then read surrounding lines):
- Faraday rescue followed by InternalServerError raise — HIGH

### Play 05: Classify Errors Honestly
File: [Play 05](.github/agents/sre/plays/05-classify-errors-honestly.md)

**What to look for:** Broad rescue blocks (bare rescue or `rescue => e`) that raise 422 UnprocessableEntity. This disguises server errors and upstream failures as client validation errors, hiding real problems from dashboards. Only specific validation exceptions should produce 422.

Grep helpers:
- `UnprocessableEntity` — search for usages, then read the rescue clause above each one

Context check (search for `UnprocessableEntity` then read the enclosing rescue block):
- Bare or broad rescue raising 422 — HIGH
- `rescue => e` followed by 422 — HIGH

### Play 06: Handle 401 Token Ownership
File: [Play 06](.github/agents/sre/plays/06-handle-401-token-ownership.md)

**What to look for:** Code that catches upstream 401 errors and blindly passes them through as 401 to clients. When our service account credentials fail upstream, that's our fault (500), not the user's (401). The key question: "Whose credentials failed — the user's or ours?"

Grep helpers:
- `rescue\s+Faraday::UnauthorizedError` — HIGH: needs context check for user vs service credentials

Context check (search for `Unauthorized` then read the rescue block):
- Upstream 401 passed through without checking credential ownership — HIGH

### Play 07: Handle 403 Permission vs Existence
File: [Play 07](.github/agents/sre/plays/07-handle-403-permission-vs-existence.md)

**What to look for:** Code that returns 403 Forbidden for non-existent resources (should be 404) or for expired/missing tokens (should be 401). Also look for `rescue ActiveRecord::RecordNotFound` that raises Forbidden — this leaks resource existence information and enables enumeration attacks.

Grep helpers:
- `Forbidden\.new.*detail.*access denied` — MEDIUM: check if this is really a permission issue or a missing resource

Context check (search for `Forbidden` and `RecordNotFound` in proximity):
- RecordNotFound rescued and converted to Forbidden — HIGH

### Play 08: Prefer Typed Exceptions
File: [Play 08](.github/agents/sre/plays/08-prefer-typed-exceptions.md)

**What to look for:** `raise 'string message'` in HTTP request paths. These become RuntimeError, fall through to the default 500 handler, and are indistinguishable from each other in APM. Should be typed exceptions that map to correct HTTP status codes.

Grep helpers:
- `raise\s+['"][^'"]+['"]` — HIGH: untyped string raise
- `raise\s+['"].*required` — HIGH: likely a missing-param error that should be ParameterMissing
- `raise\s+['"].*missing` — HIGH: likely a validation error that should be typed

### Play 09: Expected vs Unexpected Errors
File: [Play 09](.github/agents/sre/plays/09-expected-vs-unexpected-errors.md)

**What to look for:** Code that calls `span.set_error` or `set_error()` on 4xx exceptions. Expected client errors (400, 401, 404, 422) should not mark APM spans as errors — this floods error tracking with non-bugs. Only 5xx errors are unexpected and should be marked.

Grep helpers:
- `set_error\(` — HIGH: check if guarded by status >= 500
- `span\.set_error` — HIGH: check if inside a conditional for 5xx only
- `span\.set_tag.*error` — MEDIUM: manual error tagging in controllers

### Play 10: Don't Build Module-Specific Frameworks
File: [Play 10](.github/agents/sre/plays/10-dont-build-module-specific-frameworks.md)

**What to look for:** Custom logging services, error handler classes, monitoring wrappers, tracing helpers, or error classification methods built within a module. These fragment the codebase — vets-api has 24+ of these. Modules should use Rails.logger, StatsD, Datadog::Tracing, and the ExceptionHandling concern directly. Also look for `handle_error` or `handle_exception` methods embedded in service classes — these reimplement error classification that belongs in the platform layer, even without a standalone framework class.

Grep helpers:
- `class\s+\w*LogService` — HIGH: custom logging framework
- `class\s+\w*ErrorHandler` — HIGH: custom error handler
- `def\s+rescue_from` — HIGH: module-specific rescue_from override
- `def\s+(self\.)?handle_(error|exception)` — HIGH: custom error classification method in service/controller
- `class\s+\w*Monitor\b` — MEDIUM: custom monitoring class (check it's not a domain model)

### Play 11: Standardized Error Responses
File: [Play 11](.github/agents/sre/plays/11-standardized-error-responses.md)

**What to look for:** Controllers that manually render error JSON instead of raising typed exceptions. Look for `render json: { error: ... }` or custom `render_error` methods. The standard is to raise from `Common::Exceptions` and let the ExceptionHandling concern render the response.

Grep helpers:
- `render\s+json:.*\berror\b:` — HIGH: manual error rendering
- `def\s+render_error` — HIGH: custom error renderer method
- `success:\s*false` — MEDIUM: custom error field instead of standard format

---

## P2 IMPORTANT PLAYS (Tier 2+)

### Play 12: Never Return 2xx with Errors
File: [Play 12](.github/agents/sre/plays/12-never-return-2xx-with-errors.md)

**What to look for:** `render json:` in error paths that omit the `status:` parameter — Rails defaults to 200 OK. The response body contains error information but the HTTP status says success. Clients and monitoring tools see "everything is fine" when it's not.

Grep helpers:
- `render\s+json:.*\berror\b` — HIGH: check if `status:` parameter is present on the same or next line
- `success:\s*false` — MEDIUM: custom error field likely returned with 200

### Play 13: Send Retry Hints
File: [Play 13](.github/agents/sre/plays/13-send-retry-hints-to-clients.md)

**What to look for:** 429 Too Many Requests responses that don't include a `Retry-After` header — clients retry blindly instead of waiting. Also look for code that converts 429 to 503 ServiceUnavailable, which loses rate-limit semantics.

Grep helpers:
- `\[429,.*headers` — HIGH: 429 response — check if Retry-After is in headers
- `raise.*ServiceUnavailable.*TooManyRequests` — HIGH: 429 converted to 503
- `handle_429` — MEDIUM: check if Retry-After is propagated

### Play 14: Don't Mix Error Concerns
File: [Play 14](.github/agents/sre/plays/14-dont-mix-error-concerns.md)

**What to look for:** Controllers that rescue infrastructure exceptions directly (e.g., `rescue Faraday::TimeoutError` in a controller). Services should wrap infrastructure errors into domain-typed exceptions. Also look for service methods that return error objects instead of raising — callers must remember to check.

Grep helpers (scope to controller files only):
- `rescue\s+Faraday::` — HIGH: infrastructure exception in controller
- `\.error\.present\?` — MEDIUM: checking error field on a service response object (may be ActiveModel validation — read context)

### Play 15: Stable Unique Error Codes
File: [Play 15](.github/agents/sre/plays/15-stable-unique-error-codes.md)

**What to look for:** Error codes in `exceptions.en.yml` that duplicate HTTP status codes (e.g., `code: 422`) or that are shared across different error conditions. Error codes should be unique, stable, and not mimic HTTP status values.

Grep helpers (scope to `exceptions.en.yml` and error class files):
- `code:\s*\d{3}\s*$` — MEDIUM: 3-digit code that may duplicate HTTP status
- `code:\s*\d+\s*$` — MEDIUM: check for uniqueness across the file

### Play 16: Don't Swallow Errors
File: [Play 16](.github/agents/sre/plays/16-dont-swallow-errors.md)

**What to look for:** Rescue blocks that swallow errors — either by returning sentinel values (nil, false, empty collections) or by logging/emitting metrics without re-raising. The caller (or framework) never sees the exception. Especially dangerous in Sidekiq jobs where the exception is needed to trigger retries and dead queue entries, and when combined with `retry: false`.

Context check (search for `rescue` then read the rescue body):
- Rescue block whose last expression is `nil`, `false`, `[]`, or `{}` — HIGH
- Retry loops that exhaust without raising — HIGH
- Rescue block in Sidekiq `perform` that logs/emits metrics but does NOT re-raise — HIGH (job silently succeeds, no retry, no dead queue)
- Any rescue block that does not contain `raise` after logging — MEDIUM (check if caller/framework needs the exception)

### Play 17: Prefer Structured Logs
File: [Play 17](.github/agents/sre/plays/17-prefer-structured-logs.md)

**What to look for:** Logger calls with string interpolation in the message (`"Error: #{e.message}"`) instead of structured keyword arguments. Also look for manual backtrace logging (`e.backtrace.join`) — Semantic Logger handles this automatically via `exception: e`.

Grep helpers:
- `logger\.\w+\(".*#\{` — HIGH: string interpolation in log message
- `backtrace:\s*e\.backtrace` — HIGH: manual backtrace field
- `logger\.\w+.*\.message` — MEDIUM: may be logging only the message string instead of the full exception object

### Play 18: Metrics vs Logs Cardinality
File: [Play 18](.github/agents/sre/plays/18-metrics-vs-logs-cardinality.md)

**What to look for:** StatsD metric calls with high-cardinality tags — claim_id, user_id, request_id, or raw params in the `tags:` array. These create millions of unique time series and cause Datadog cost explosion. Unique identifiers belong in log fields, not metric tags.

Grep helpers:
- `StatsD\.\w+.*tags:.*claim_id` — HIGH
- `StatsD\.\w+.*tags:.*user_id` — HIGH
- `StatsD\.\w+.*tags:.*params` — HIGH
- `StatsD\.\w+.*tags:.*request_id` — HIGH

### Play 19: Validate at Boundaries
File: [Play 19](.github/agents/sre/plays/19-validate-at-boundaries-fail-fast.md)

**What to look for:** Parameter validation that happens deep in service methods or getters instead of at the controller boundary. Also look for `raise 'missing param'` style string raises for validation errors — these should be typed exceptions (ParameterMissing, UnprocessableEntity).

Grep helpers:
- `raise\s+['"].*missing.*param` — HIGH: untyped validation raise
- `raise\s+['"].*malformed` — HIGH: untyped validation raise

Context check (search for `params[` in service/lib files):
- Late validation in a helper method called after state mutation — MEDIUM

### Play 20: Don't Catch-Log-Reraise
File: [Play 20](.github/agents/sre/plays/20-dont-catch-log-reraise.md)

**What to look for:** Rescue blocks that log the error and then re-raise the same exception. This produces duplicate error entries — one from the manual log and one from APM when the exception propagates. Also look for manual `e.backtrace.join("\n")` logging which duplicates APM's automatic backtrace capture.

Grep helpers:
- `\.backtrace\.join` — HIGH: manual backtrace logging

Context check (search for `logger\.(error|warn)` inside rescue blocks, then check if followed by `raise`):
- Log then re-raise same exception — HIGH
- Log `.message` then re-raise — HIGH

### Play 21: Respect Retry Headers
File: [Play 21](.github/agents/sre/plays/21-respect-retry-headers-when-calling-upstream.md)

**What to look for:** Sidekiq jobs that log ERROR on every retry attempt (should log WARN for retries, ERROR only when exhausted). Custom retry helpers that use bare rescue (catches code bugs, not just transient failures). Retry loops that exhaust silently and return nil instead of raising.

Grep helpers:
- `sidekiq_options\s+retry:\s*\d+` — entry point: read the job's rescue block for ERROR logging on every attempt

Context check (search for `retry` keyword then read surrounding rescue block):
- Bare rescue with retry — MEDIUM: catches code bugs, not just transient errors
- Retry loop that returns nil on exhaustion instead of raising — HIGH
