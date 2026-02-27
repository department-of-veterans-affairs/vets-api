# Detection Patterns by Play

> **Do No Harm (Iron Law #0):** Pattern matches are *candidates*, not findings. Every match below must pass through the investigation gates and false-positive checks in its play file before being flagged. If any gate produces ambiguity, exclude the candidate. It is always better to miss a real anti-pattern than to flag correct code.

Read this file as the first step of every audit. For each play, use the **What to look for** description to understand the violation, then use **Grep helpers** (where provided) as starting points for `search`. For patterns that span multiple lines, search for the entry-point line and then `read` surrounding context to confirm.

After finding a match, read the play file for rules, false-positive heuristics, and `<false_positive>` exclusions in the `<severity_assessment>` block before flagging.

**Output format reminder:** Report findings under `### Play NN: Play Name — SEVERITY` headings. Each finding gets `#### N. \`file:line\` — CONFIDENCE` with a code snippet. See Iron Laws in sre.agent.md.

**Confidence levels:**
- `HIGH` — Flag if confirmed after reading context (outside test files)
- `MEDIUM` — Read 10-20 lines of surrounding context; check play file for false positives

**General exclusions:** Skip `spec/`, `test/`, and `fixtures/` directories unless a play specifically notes otherwise.

---

## P1 CRITICAL PLAYS (Tier 1+)

### Play 01: Don't Leak PII/PHI/Secrets
File: [Play 01](.github/agents/sre/plays/01-dont-leak-pii-phi-secrets.xml)

**What to look for:** Exception messages or log statements that include raw response bodies, user params, or data that could contain PII/PHI (names, SSNs, medical info) or secrets (API keys, tokens). Common pattern: `raise` or `logger.error` with `.body` or raw `params` interpolated into the message or metadata.

Grep helpers:
- `raise\s+".*resp\.body` — HIGH: raise with response body inline
- `raise\s+".*response.*body` — HIGH: raise referencing response body
- `logger\.\w+.*\.body` — MEDIUM: logger call referencing .body
- `meta:.*params` — MEDIUM: raw params passed as log metadata

### Play 02: Preserve Cause Chains
File: [Play 02](.github/agents/sre/plays/02-preserve-cause-chains.xml)

**What to look for:** Rescue blocks that catch an exception and raise a new one in a way that destroys the cause chain. The main anti-pattern is converting an exception to a string with `raise "error: #{e}"` which creates a RuntimeError and loses the original class, backtrace, and cause chain. Ruby automatically preserves the cause chain when you `raise` a new exception inside a `rescue` block (`$!.cause` is set implicitly), so the fix is usually `raise TypedError.new(detail)` or bare `raise`. Do NOT recommend `cause: e` with `Common::Exceptions` classes — they don't accept it.

Note: `raise e` inside `rescue => e` DOES preserve the cause chain (Ruby sets `cause` implicitly). Only flag when a *different* exception class is raised without `cause:`.

Grep helpers:
- `raise\s+".*#\{.*\}"` — HIGH: stringified re-raise destroys cause chain
- `raise\s+\w+\.new\(.*\.message\)` — HIGH: wraps only the message, drops the exception object
- `raise\s+\w+Exception\.new\([^)]*\)\s*$` — MEDIUM: new exception without `cause:` keyword — read context to check if inside a rescue block
- `raise\s+Common::Exceptions::\w+\s*$` — MEDIUM: raises a platform exception without arguments — check if inside a rescue block (if so, cause chain is broken because the original exception is discarded)
- `raise\s+[A-Z]\w+::\w+\s*$` — MEDIUM: raises a namespaced exception with no args inside a rescue — read context to confirm rescue block

### Play 03: Never Use Bare Rescues
File: [Play 03](.github/agents/sre/plays/03-never-use-bare-rescues.xml)

**What to look for:** Rescue blocks without an exception class (`rescue`, `rescue => e`, or `rescue Exception`). These catch everything including `NoMethodError` from typos and `SignalException` from Ctrl+C. Also look for rescue blocks that return nil, false, or empty collections — signals of error swallowing combined with bare rescue.

Grep helpers:
- `rescue\s*$` — HIGH: bare rescue on its own line
- `rescue\s*=>\s*\w+` — HIGH: `rescue => e` without exception class
- `rescue\s+Exception\b` — HIGH: catches system signals and exits

Context check (search for `rescue` then read surrounding lines):
- Rescue block followed by `nil`, `false`, `[]`, or `{}` return — MEDIUM

### Play 04: Map Upstream Network Errors
File: [Play 04](.github/agents/sre/plays/04-map-upstream-network-errors-correctly.xml)

**What to look for:** Rescue blocks that catch Faraday errors (timeouts, connection failures, upstream 5xx) and map them to `InternalServerError` (500). Upstream failures should map to 502/503/504, not 500 — a 500 means our code is broken. Also look for catching all Faraday errors with a single rescue clause and returning one status code.

Grep helpers:
- `raise.*InternalServerError.*exception:\s*e` — HIGH: wrapping upstream error as 500
- `rescue\s+Faraday::ClientError,\s*Faraday::ServerError` — MEDIUM: blanket catch of all Faraday errors

Context check (search for `rescue\s+Faraday::` then read surrounding lines):
- Faraday rescue followed by InternalServerError raise — HIGH

### Play 05: Classify Errors Honestly
File: [Play 05](.github/agents/sre/plays/05-classify-errors-honestly.xml)

**What to look for:** Broad rescue blocks (bare rescue or `rescue => e`) that raise 422 UnprocessableEntity. This disguises server errors and upstream failures as client validation errors, hiding real problems from dashboards. Only specific validation exceptions should produce 422.

Grep helpers:
- `UnprocessableEntity` — search for usages, then read the rescue clause above each one

Context check (search for `UnprocessableEntity` then read the enclosing rescue block):
- Bare or broad rescue raising 422 — HIGH
- `rescue => e` followed by 422 — HIGH

### Play 06: Handle 401 Token Ownership
File: [Play 06](.github/agents/sre/plays/06-handle-401-token-ownership.xml)

**What to look for:** Code that catches upstream 401 errors and blindly passes them through as 401 to clients. When our service account credentials fail upstream, that's our fault (500), not the user's (401). The key question: "Whose credentials failed — the user's or ours?"

Grep helpers:
- `rescue\s+Faraday::UnauthorizedError` — HIGH: needs context check for user vs service credentials

Context check (search for `Unauthorized` then read the rescue block):
- Upstream 401 passed through without checking credential ownership — HIGH

### Play 07: Handle 403 Permission vs Existence
File: [Play 07](.github/agents/sre/plays/07-handle-403-permission-vs-existence.xml)

**What to look for:** Code that returns 403 Forbidden for non-existent resources (should be 404) or for expired/missing tokens (should be 401). Also look for `rescue ActiveRecord::RecordNotFound` that raises Forbidden — this leaks resource existence information and enables enumeration attacks.

Grep helpers:
- `Forbidden\.new.*detail.*access denied` — MEDIUM: check if this is really a permission issue or a missing resource

Context check (search for `Forbidden` and `RecordNotFound` in proximity):
- RecordNotFound rescued and converted to Forbidden — HIGH

### Play 08: Prefer Typed Exceptions
File: [Play 08](.github/agents/sre/plays/08-prefer-typed-exceptions.xml)

**What to look for:** `raise 'string message'` in HTTP request paths. These become RuntimeError, fall through to the default 500 handler, and are indistinguishable from each other in APM. Should be typed exceptions that map to correct HTTP status codes.

Grep helpers:
- `raise\s+['"][^'"]+['"]` — HIGH: untyped string raise
- `raise\s+['"].*required` — HIGH: likely a missing-param error that should be ParameterMissing
- `raise\s+['"].*missing` — HIGH: likely a validation error that should be typed

### Play 09: Expected vs Unexpected Errors
File: [Play 09](.github/agents/sre/plays/09-expected-vs-unexpected-errors.xml)

**What to look for:** Code that calls `span.set_error` or `set_error()` on 4xx exceptions. Expected client errors (400, 401, 404, 422) should not mark APM spans as errors — this floods error tracking with non-bugs. Only 5xx errors are unexpected and should be marked.

Grep helpers:
- `set_error\(` — HIGH: check if guarded by status >= 500
- `span\.set_error` — HIGH: check if inside a conditional for 5xx only
- `span\.set_tag.*error` — MEDIUM: manual error tagging in controllers

### Play 10: Don't Build Module-Specific Frameworks
File: [Play 10](.github/agents/sre/plays/10-dont-build-module-specific-frameworks.xml)

**What to look for:** Custom logging services, error handler classes, monitoring wrappers, tracing helpers, or error classification methods built within a module. These fragment the codebase — vets-api has 24+ of these. Modules should use Rails.logger, StatsD, Datadog::Tracing, and the ExceptionHandling concern directly. Also look for `handle_error` or `handle_exception` methods embedded in service classes — these reimplement error classification that belongs in the platform layer, even without a standalone framework class.

Grep helpers:
- `class\s+\w*LogService` — HIGH: custom logging framework
- `class\s+\w*ErrorHandler` — HIGH: custom error handler
- `def\s+rescue_from` — HIGH: module-specific rescue_from override
- `def\s+(self\.)?handle_(error|exception)` — HIGH: custom error classification method in service/controller
- `class\s+\w*Monitor\b` — MEDIUM: custom monitoring class (check it's not a domain model)

