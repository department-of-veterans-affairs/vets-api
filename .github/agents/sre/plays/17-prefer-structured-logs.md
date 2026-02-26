---
id: prefer-structured-logs
title: Prefer structured logs; use Rails Semantic Logger exception handling
severity: HIGH
---

<!--
<agent_play>

  <context>
    String interpolation prevents field-level queries, so you cannot
    search by file_path, and every unique string becomes a different log
    message, causing cardinality explosion. Logging e.message instead of
    the exception object loses the backtrace, so APM sees the message
    but the stack trace is gone and you cannot find the failure
    location. A manual backtrace field bypasses Semantic Logger, causing
    the exception class and cause chain to be lost so APM cannot trace
    the root cause. Unstructured logs cannot be aggregated or alerted
    on, so Datadog sees 10,000 unique messages that are actually a
    single pattern.
  </context>

  <applies_to>
    <glob>app/controllers/**/*.rb</glob>
    <glob>app/sidekiq/**/*.rb</glob>
    <glob>lib/**/*.rb</glob>
    <glob>modules/*/app/**/*.rb</glob>
    <glob>modules/*/lib/**/*.rb</glob>
  </applies_to>

  <related_plays>
    <play id="dont-catch-log-reraise" relationship="complementary" />
    <play id="metrics-vs-logs-cardinality" relationship="complementary" />
  </related_plays>

  <rules>
    <rule enforcement="must">
      Pass the exception object via the `exception:` key to Rails
      Semantic Logger — this records the class, message, backtrace,
      and cause chain in one event.
    </rule>
    <rule enforcement="must">
      Pass dynamic values as keyword arguments (structured fields)
      — string interpolation prevents DataDog from grouping events
      and causes cardinality explosion.
    </rule>
    <rule enforcement="must">
      Log structured fields alongside exceptions: event, code,
      status, service, operation, request_id/correlation_id,
      error_class, duration_ms, safe domain IDs.
    </rule>
    <rule enforcement="must">
      Verify log fields contain no PII, PHI, or secrets — no
      free-text concatenation of params or request bodies.
    </rule>
  </rules>

  <investigate_before_answering>
    <step>Read the full method containing the logger call to understand what dynamic values are being interpolated and whether they are safe to log as fields.</step>
    <step>Determine whether the logger call is inside a rescue block. If so, check whether the exception object (`e`) is available and should be passed via `exception: e` instead of `e.message`.</step>
    <step>Check whether the logger call includes `backtrace: e.backtrace` — if so, this should be replaced with `exception: e` which captures the backtrace automatically along with exception class and cause chain.</step>
    <step>Verify that the suggested structured fields do not contain PII, PHI, or secrets. Values like `user_id`, `ssn`, `request.body` must not appear as log fields.</step>
    <step>Check whether the message string is used in any alerting rules or DataDog monitors. Changing the message may require updating monitors.</step>
  </investigate_before_answering>

  <severity_assessment>
    <critical>string interpolation in logger call that includes PII, PHI, or
secrets (e.g., user names, SSNs, tokens)</critical>
    <critical>manual backtrace logging in code handling benefits claims or
financial data</critical>
    <high>string interpolation in logger call inside rescue block —
loses both structure and backtrace</high>
    <high>backtrace: e.backtrace instead of exception: e — loses
exception class and cause chain</high>
    <medium>string interpolation in info-level logger call with low-
cardinality values</medium>
  </severity_assessment>

  <pr_comment_template>
    **Prefer structured logs** | `HIGH`

    `{{file_path}}:{{line_number}}` -- {{one_line_violation_description}}

    **Why this matters:** String interpolation in log messages prevents DataDog
    from grouping events. Each unique value creates a separate pattern, causing
    cardinality explosion. Structured keyword arguments make every field queryable
    and aggregatable.

    **Suggested fix:**
    ```ruby
    {{suggested_code}}
    ```

    - [ ] No string interpolation in log message (static string only)
    - [ ] Exception object passed via `exception: e` (not `e.message`)
    - [ ] No manual `backtrace:` field (Semantic Logger handles it)
    - [ ] All structured fields are safe to log (no PII/PHI/secrets)

    [Play: Prefer structured logs](17-prefer-structured-logs.md)
  </pr_comment_template>

</agent_play>
-->

### Do

- Pass the exception object via `exception: e` to Rails Semantic Logger:
  ```ruby
  Rails.logger.error('Error stamping form for PdfFill',
                     file_path: file_path,
                     exception: e)
  ```
- Log structured fields as keyword arguments (not string interpolation):
  ```ruby
  Rails.logger.info('EPS presentation filter applied',
                    debug_category: 'eps',
                    kept_facilities: eps_after_facilities,
                    removed_facilities: removed_facilities)
  ```
- Use safe, low-cardinality field names (`operation`, `service`, `error_code`, `form_version`)

### Don't

- Use string interpolation in log messages:
  ```ruby
  # BAD: each unique file_path creates a different log pattern
  Rails.logger.error("Error stamping form for PdfFill: #{file_path}, error: #{e.message}")
  ```
- Log `e.message` instead of the full exception object:
  ```ruby
  # BAD: loses backtrace, exception class, and cause chain
  Rails.logger.error("Failed: #{e.message}")
  ```
- Emit a second log entry with `backtrace: e.backtrace`:
  ```ruby
  # BAD: bypasses Semantic Logger's built-in exception handling
  Rails.logger.error("Failed", backtrace: e.backtrace)
  ```
- Log request bodies or secrets -- no free-text concatenation of params

## Anti-Patterns

#### String Interpolation Loses Structure

##### Anti-Pattern

```ruby
Rails.logger.error("Error stamping form for PdfFill: #{file_path}, error: #{e.message}")
# String interpolation prevents querying by file_path or error as fields
# Calling e.message loses exception backtrace
```

##### Golden Pattern

```ruby
Rails.logger.error('Error stamping form for PdfFill',
                   file_path: file_path,
                   exception: e)  # Preserves message + backtrace, queryable fields
```

#### Debug Prefix in Unstructured String

##### Anti-Pattern

```ruby
removed_msg = removed_facilities.any? ? ", removed #{removed_facilities}" : ''
Rails.logger.info("EPS Debug: Presentation filter kept #{eps_after_facilities}#{removed_msg}")
# Cannot query by eps_after_facilities or removed_facilities
# String concatenation instead of structured fields
```

##### Golden Pattern

```ruby
Rails.logger.info('EPS presentation filter applied',
                  debug_category: 'eps',
                  kept_facilities: eps_after_facilities,
                  removed_facilities: removed_facilities)  # All fields queryable
```

#### Manual Backtrace Field Loses Exception Object

##### Anti-Pattern

```ruby
def log_error(e)
  message = e.original_body['errorMessageList'] || e.original_body['error']
  Rails.logger.error("Failed to retrieve Ch. 31 eligibility details: #{message}",
                     backtrace: e.backtrace)
  # String interpolation in message
  # Manual backtrace: field loses exception class and cause chain
end
```

##### Golden Pattern

```ruby
def log_error(e)
  Rails.logger.error('Failed to retrieve Ch. 31 eligibility details',
                     exception: e,  # Automatically captures class, message, backtrace, cause
                     error_code: e.original_body['error'])
end
```
