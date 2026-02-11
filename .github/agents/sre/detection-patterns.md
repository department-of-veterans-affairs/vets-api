# Detection Patterns by Play

Read this file as the first step of every audit. Use these patterns with `search` (grep) to find potential violations, then read the play file for rules, false-positive heuristics, and investigation steps before flagging.

**Pattern confidence levels:**
- `[HIGH]` — Always flag if pattern matches (outside test files)
- `[MEDIUM]` — Read 10-20 lines of context before flagging; check play file for false-positive heuristics

**General exclusions:** Skip `spec/`, `test/`, and `fixtures/` directories unless a play specifically notes otherwise.

---

## P1 CRITICAL PLAYS (Tier 1+)

### Play 01: Don't Leak PII/PHI/Secrets
File: `plays/01-dont-leak-pii-phi-secrets.md`
- [HIGH] response_body_in_raise: `raise\s+".*resp\.body`
- [HIGH] response_body_keyword_in_raise: `raise\s+".*response.*body`
- [MEDIUM] logger_with_response_body: `logger\.\w+.*\.body`
- [MEDIUM] params_in_meta: `meta:.*params`

### Play 02: Preserve Cause Chains
File: `plays/02-preserve-cause-chains.md`
- [MEDIUM] raise_new_exception_without_cause: `raise\s+\w+Exception\.new\([^)]*\)\s*$`
- [HIGH] stringified_reraise: `raise\s+".*#\{.*\}"`
- [HIGH] wrap_with_message_only: `raise\s+\w+\.new\(.*\.message\)`

### Play 03: Never Use Bare Rescues
File: `plays/03-never-use-bare-rescues.md`
- [HIGH] bare_rescue_no_class: `rescue\s*$`
- [HIGH] rescue_hashrocket_no_class: `rescue\s*=>\s*\w+`
- [HIGH] rescue_exception_class: `rescue\s+Exception\b`
- [MEDIUM] rescue_nil_return: `rescue.*\n\s*(nil|false|\[\]|\{\})\s*$`

### Play 04: Map Upstream Network Errors
File: `plays/04-map-upstream-network-errors-correctly.md`
- [HIGH] faraday_error_to_internal_server_error: `rescue\s+Faraday::\w+.*\n.*InternalServerError`
- [MEDIUM] faraday_blanket_catch: `rescue\s+Faraday::ClientError,\s*Faraday::ServerError`
- [HIGH] upstream_to_500_with_exception: `raise.*InternalServerError.*exception:\s*e`

### Play 05: Classify Errors Honestly
File: `plays/05-classify-errors-honestly.md`
- [HIGH] bare_rescue_returning_422: `rescue\s*=>\s*e.*\n.*raise.*UnprocessableEntity`
- [MEDIUM] catch_all_then_422: `rescue.*\n.*raise.*422`
- [MEDIUM] broad_rescue_to_unprocessable_entity: `rescue\s+.*Error.*\n.*raise.*UnprocessableEntity`

### Play 06: Handle 401 Token Ownership
File: `plays/06-handle-401-token-ownership.md`
- [HIGH] blind_401_passthrough: `rescue\s+.*UnauthorizedError.*\n.*raise.*Unauthorized`
- [MEDIUM] upstream_auth_raise: `raise.*Unauthorized.*upstream.*auth`
- [HIGH] faraday_unauthorized_no_service_check: `rescue\s+Faraday::UnauthorizedError`

### Play 07: Handle 403 Permission vs Existence
File: `plays/07-handle-403-permission-vs-existence.md`
- [HIGH] forbidden_with_record_not_found: `raise.*Forbidden.*\n.*RecordNotFound|RecordNotFound.*\n.*Forbidden`
- [MEDIUM] forbidden_access_denied: `Forbidden\.new.*detail.*access denied`
- [HIGH] rescue_not_found_raises_forbidden: `rescue\s+ActiveRecord::RecordNotFound.*\n.*Forbidden`

### Play 08: Prefer Typed Exceptions
File: `plays/08-prefer-typed-exceptions.md`
- [HIGH] untyped_string_raise: `raise\s+['"][^'"]+['"]`
- [HIGH] untyped_raise_required: `raise\s+['"].*required`
- [HIGH] untyped_raise_missing: `raise\s+['"].*missing`

### Play 09: Expected vs Unexpected Errors
File: `plays/09-expected-vs-unexpected-errors.md`
- [HIGH] set_error_without_status_check: `set_error\(`
- [HIGH] span_set_error_in_controller: `span\.set_error`
- [MEDIUM] span_set_tag_error_in_rescue: `span\.set_tag.*error`

### Play 10: Don't Build Module-Specific Frameworks
File: `plays/10-dont-build-module-specific-frameworks.md`
- [HIGH] custom_log_service_class: `class\s+\w*LogService`
- [MEDIUM] custom_monitor_class: `class\s+\w*Monitor\b`
- [HIGH] custom_error_handler_class: `class\s+\w*ErrorHandler`
- [HIGH] custom_rescue_from_in_module: `def\s+rescue_from`

### Play 11: Standardized Error Responses
File: `plays/11-standardized-error-responses.md`
- [HIGH] manual_error_rendering: `render\s+json:.*\berror\b:`
- [HIGH] render_error_without_status: `render\s+json:.*\berror\b.*(?!status)`
- [HIGH] custom_error_renderer_method: `def\s+render_error`
- [MEDIUM] success_false_field: `success:\s*false`

---

## P2 IMPORTANT PLAYS (Tier 2+)

### Play 12: Never Return 2xx with Errors
File: `plays/12-never-return-2xx-with-errors.md`
- [HIGH] render_error_without_status: `render\s+json:.*error.*(?!status)`
- [MEDIUM] custom_success_false_field: `success:\s*false`
- [HIGH] render_error_no_status_multiline: `render\s+json:.*\berror\b.*$`

### Play 13: Send Retry Hints
File: `plays/13-send-retry-hints-to-clients.md`
- [HIGH] 429_response_missing_retry_after: `\[429,.*headers`
- [HIGH] 429_converted_to_503: `raise.*ServiceUnavailable.*TooManyRequests`
- [MEDIUM] handle_429_without_retry_after: `handle_429`

### Play 14: Don't Mix Error Concerns
File: `plays/14-dont-mix-error-concerns.md`
- [HIGH] controller_catches_http_client: `rescue\s+Faraday::` (only in controller files)
- [MEDIUM] response_error_field_check: `\.error\.present\?`
- [HIGH] http_like_response_with_error: `status:\s*200.*error:`

### Play 15: Stable Unique Error Codes
File: `plays/15-stable-unique-error-codes.md`
- [HIGH] duplicate_code_values_in_yaml: `code:\s*(\d+)` (check for duplicates across exceptions.en.yml)
- [MEDIUM] http_status_as_error_code: `code:\s*\d{3}\s*$` (where code matches status on nearby line)
- [MEDIUM] non_namespaced_numeric_code: `code:\s*\d+\s*$`

### Play 16: Don't Swallow Errors
File: `plays/16-dont-swallow-errors.md`
- [HIGH] rescue_returning_nil: `rescue.*\n\s*nil\s*$`
- [HIGH] rescue_returning_false: `rescue.*\n\s*false\s*$`
- [MEDIUM] rescue_returning_empty_array: `rescue.*\n\s*\[\]\s*$`
- [MEDIUM] rescue_returning_empty_hash: `rescue.*\n\s*\{\}\s*$`

### Play 17: Prefer Structured Logs
File: `plays/17-prefer-structured-logs.md`
- [HIGH] string_interpolation_in_log_message: `logger\.\w+\(".*#\{`
- [HIGH] manual_backtrace_field: `backtrace:\s*e\.backtrace`
- [MEDIUM] logging_only_exception_message: `logger\.\w+.*\.message`

### Play 18: Metrics vs Logs Cardinality
File: `plays/18-metrics-vs-logs-cardinality.md`
- [HIGH] claim_id_in_metric_tags: `StatsD\.\w+.*tags:.*claim_id`
- [HIGH] user_id_in_metric_tags: `StatsD\.\w+.*tags:.*user_id`
- [HIGH] params_in_metric_tags: `StatsD\.\w+.*tags:.*params`
- [HIGH] request_id_in_metric_tags: `StatsD\.\w+.*tags:.*request_id`

### Play 19: Validate at Boundaries
File: `plays/19-validate-at-boundaries-fail-fast.md`
- [HIGH] untyped_raise_missing_param: `raise\s+['"].*missing.*param`
- [HIGH] untyped_raise_malformed: `raise\s+['"].*malformed`
- [MEDIUM] late_validation_in_getter: `def\s+get_\w+.*\n.*params\[.*\n.*raise\s+['"]`

### Play 20: Don't Catch-Log-Reraise
File: `plays/20-dont-catch-log-reraise.md`
- [HIGH] catch_log_reraise: `rescue.*\n.*logger\.(error|warn).*\n.*raise\b`
- [HIGH] manual_backtrace_logging: `\.backtrace\.join`
- [HIGH] log_message_then_raise: `logger\.(error|warn).*\.message.*\n.*raise\b`

### Play 21: Respect Retry Headers
File: `plays/21-respect-retry-headers-when-calling-upstream.md`
- [HIGH] sidekiq_retry_with_error_logging: `sidekiq_options\s+retry:\s*\d+` (check for logger.error in rescue block)
- [MEDIUM] bare_rescue_with_retry: `rescue\s*=>\s*e\n.*retry\b`
- [MEDIUM] sleep_retry_without_exception_filter: `sleep\s+delay.*\n.*retry\b`
