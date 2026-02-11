# Play 17: Prefer Structured Logs; Use Rails Semantic Logger Exception Handling

## Context
String interpolation prevents field-level queries, so you cannot search by file_path, and every unique string becomes a different log message, causing cardinality explosion. Logging e.message instead of the exception object loses the backtrace, so APM sees the message but the stack trace is gone and you cannot find the failure location. A manual backtrace field bypasses Semantic Logger, causing the exception class and cause chain to be lost so APM cannot trace the root cause. Unstructured logs cannot be aggregated or alerted on, so Datadog sees 10,000 unique messages that are actually a single pattern.

## Applies To
- `app/controllers/**/*.rb`
- `app/sidekiq/**/*.rb`
- `lib/**/*.rb`
- `modules/*/app/**/*.rb`
- `modules/*/lib/**/*.rb`

## Investigation Steps
1. Read the full method containing the logger call to understand what dynamic values are being interpolated and whether they are safe to log as fields.
2. Determine whether the logger call is inside a rescue block. If so, check whether the exception object (`e`) is available and should be passed via `exception: e` instead of `e.message`.
3. Check whether the logger call includes `backtrace: e.backtrace` -- if so, this should be replaced with `exception: e` which captures the backtrace automatically along with exception class and cause chain.
4. Verify that the suggested structured fields do not contain PII, PHI, or secrets. Values like `user_id`, `ssn`, `request.body` must not appear as log fields.
5. Check whether the message string is used in any alerting rules or DataDog monitors. Changing the message may require updating monitors.

## Severity Assessment
- **CRITICAL:** String interpolation in logger call that includes PII, PHI, or secrets (e.g., user names, SSNs, tokens)
- **CRITICAL:** Manual backtrace logging in code handling benefits claims or financial data
- **HIGH:** String interpolation in logger call inside rescue block -- loses both structure and backtrace
- **HIGH:** `backtrace: e.backtrace` instead of `exception: e` -- loses exception class and cause chain
- **MEDIUM:** String interpolation in info-level logger call with low-cardinality values

## Golden Patterns

### Do
Pass the exception object via `exception: e` to Rails Semantic Logger:
```ruby
Rails.logger.error('Error stamping form for PdfFill',
                   file_path: file_path,
                   exception: e)
```

Log structured fields as keyword arguments (not string interpolation):
```ruby
Rails.logger.info('EPS presentation filter applied',
                  debug_category: 'eps',
                  kept_facilities: eps_after_facilities,
                  removed_facilities: removed_facilities)
```

Use safe, low-cardinality field names (`operation`, `service`, `error_code`, `form_version`).

### Don't
Use string interpolation in log messages:
```ruby
# BAD: each unique file_path creates a different log pattern
Rails.logger.error("Error stamping form for PdfFill: #{file_path}, error: #{e.message}")
```

Log `e.message` instead of the full exception object:
```ruby
# BAD: loses backtrace, exception class, and cause chain
Rails.logger.error("Failed: #{e.message}")
```

Emit a second log entry with `backtrace: e.backtrace`:
```ruby
# BAD: bypasses Semantic Logger's built-in exception handling
Rails.logger.error("Failed", backtrace: e.backtrace)
```

Log request bodies or secrets -- no free-text concatenation of params.

## Anti-Patterns

### String Interpolation Loses Structure
**Anti-pattern:**
```ruby
Rails.logger.error("Error stamping form for PdfFill: #{file_path}, error: #{e.message}")
```
**Problem:** String interpolation prevents querying by file_path or error as fields. Calling e.message loses exception backtrace. Every unique file path creates cardinality explosion.

**Corrected:**
```ruby
Rails.logger.error('Error stamping form for PdfFill',
                   file_path: file_path,
                   exception: e)
```

### Debug Prefix in Unstructured String
**Anti-pattern:**
```ruby
removed_msg = removed_facilities.any? ? ", removed #{removed_facilities}" : ''
Rails.logger.info("EPS Debug: Presentation filter kept #{eps_after_facilities}#{removed_msg}")
```
**Problem:** Cannot query by eps_after_facilities or removed_facilities. String concatenation makes automated parsing impossible. Cannot generate metrics from facility counts.

**Corrected:**
```ruby
Rails.logger.info('EPS presentation filter applied',
                  debug_category: 'eps',
                  kept_facilities: eps_after_facilities,
                  removed_facilities: removed_facilities)
```

### Manual Backtrace Field Loses Exception Object
**Anti-pattern:**
```ruby
def log_error(e)
  message = e.original_body['errorMessageList'] || e.original_body['error']
  Rails.logger.error("Failed to retrieve Ch. 31 eligibility details: #{message}",
                     backtrace: e.backtrace)
end
```
**Problem:** `backtrace:` field loses exception class name (only shows stack trace array). Cause chain is lost (no visibility into wrapped exceptions). String interpolation of message creates cardinality explosion. Semantic Logger's exception handling is bypassed.

**Corrected:**
```ruby
def log_error(e)
  Rails.logger.error('Failed to retrieve Ch. 31 eligibility details',
                     exception: e,
                     error_code: e.original_body['error'])
end
```

## Finding Template
**Prefer structured logs** | `HIGH`

`{{file_path}}:{{line_number}}` -- {{one_line_violation_description}}

**Why this matters:** String interpolation in log messages prevents DataDog from grouping events. Each unique value creates a separate pattern, causing cardinality explosion. Structured keyword arguments make every field queryable and aggregatable.

**Suggested fix:**
```ruby
{{suggested_code}}
```

- [ ] No string interpolation in log message (static string only)
- [ ] Exception object passed via `exception: e` (not `e.message`)
- [ ] No manual `backtrace:` field (Semantic Logger handles it)
- [ ] All structured fields are safe to log (no PII/PHI/secrets)

[Play: Prefer structured logs](plays/prefer-structured-logs.md)

## Verify Commands
```bash
# No string interpolation in logger calls in changed file
grep -On 'logger\.\w+\(".*#\{' {{file_path}} && exit 1 || exit 0

# No manual backtrace field in changed file
grep -On 'backtrace:\s*e\.backtrace' {{file_path}} && exit 1 || exit 0

# Run specs for changed file
bundle exec rspec {{spec_path}}

# RuboCop passes for changed file
bundle exec rubocop {{file_path}}
```

## Related Plays
- Play: dont-catch-log-reraise (complementary)
- Play: metrics-vs-logs-cardinality (complementary)
