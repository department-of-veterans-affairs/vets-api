---
id: prefer-structured-logs
title: Prefer structured logs; use Rails Semantic Logger exception handling
version: 1
severity: HIGH
category: observability
tags:
- structured-logging
- semantic-logger
- datadog
- cardinality
- exception-logging
language: ruby
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

  <retrieval_triggers>
    <trigger>string interpolation in logger call prevents querying</trigger>
    <trigger>logging e.message loses backtrace and exception class</trigger>
    <trigger>manual backtrace field instead of exception parameter</trigger>
    <trigger>unstructured log messages create cardinality explosion</trigger>
    <trigger>DataDog cannot aggregate logs with string interpolation</trigger>
  </retrieval_triggers>

  <detection>
    <pattern name="string_interpolation_in_log_message" confidence="high">
      <signature>logger\.\w+\(".*#\{</signature>
      <description>
        A logger call whose message string contains Ruby string
        interpolation (`#{}`). Each unique interpolated value produces
        a distinct log message, preventing DataDog from grouping them
        into a single pattern. Fields embedded in the string cannot be
        queried, filtered, or used in alerts.
      </description>
      <example>Rails.logger.error("Error stamping form for PdfFill: #{file_path}, error: #{e.message}")</example>
      <example>Rails.logger.info("EPS Debug: Presentation filter kept #{eps_after_facilities}#{removed_msg}")</example>
      <example>Rails.logger.error("Failed to retrieve Ch. 31 eligibility details: #{message}")</example>
    </pattern>
    <pattern name="manual_backtrace_field" confidence="high">
      <signature>backtrace:\s*e\.backtrace</signature>
      <description>
        Passing `backtrace: e.backtrace` as a log field instead of
        using `exception: e`. This bypasses Semantic Logger's
        exception handling, which automatically records the exception
        class, message, full backtrace, and cause chain. The manual
        field loses the exception class and cause chain, so APM cannot
        trace root causes.
      </description>
      <example>Rails.logger.error("Failed", backtrace: e.backtrace)</example>
      <example>logger.error("Error occurred", backtrace: e.backtrace)</example>
    </pattern>
    <pattern name="logging_only_exception_message" confidence="medium">
      <signature>logger\.\w+.*\.message</signature>
      <description>
        Logging `e.message` instead of passing the full exception
        object via `exception: e`. The message string alone loses the
        exception class, backtrace, and cause chain. Medium confidence
        because `.message` may refer to a non-exception variable in
        some contexts — check whether the variable is an exception
        object.
      </description>
      <example>Rails.logger.error("Error: #{e.message}")</example>
      <example>Rails.logger.warn("Service failed: #{error.message}")</example>
    </pattern>
    <heuristic>
      A logger call inside a rescue block that references
      `e.message` or interpolates exception details into the message
      string is a strong signal. The developer intended to capture
      the error but used string interpolation instead of structured
      fields, losing queryability and backtrace.
    </heuristic>
    <heuristic>
      Any logger call with more than one `#{}` interpolation in the
      message string is almost certainly losing structure. Each
      interpolated value should be a separate keyword argument for
      DataDog to index.
    </heuristic>
    <heuristic>
      A logger call that passes `backtrace:` as a keyword argument
      alongside a string-interpolated message indicates the
      developer knew backtrace mattered but bypassed Semantic
      Logger's built-in exception handling.
    </heuristic>
    <false_positive>
      Logger calls with string interpolation for a single static
      identifier (e.g., a class name or module constant) where the
      interpolated value is low-cardinality and fixed at deploy
      time. Example: `Rails.logger.info("#{self.class.name}
      initialized")` — acceptable only when the class set is small
      and fixed.
    </false_positive>
    <false_positive>
      Logger calls in test/spec code where structured logging is not
      required. Test helpers may use string interpolation for
      readability without impacting production observability.
    </false_positive>
  </detection>

  <rules>
    <rule enforcement="must">
      Use Rails Semantic Logger and pass the exception object via
      the `exception:` key — this records the message and backtrace
      in one event.
    </rule>
    <rule enforcement="must">
      Log structured fields alongside the exception: event, code,
      status, service, operation, request_id/correlation_id,
      error_class, duration_ms, safe domain IDs.
    </rule>
    <rule enforcement="must_not">
      Never use string interpolation in log messages — pass dynamic
      values as keyword arguments for DataDog queryability.
    </rule>
    <rule enforcement="must_not">
      Never emit a second log entry with the backtrace — Semantic
      Logger already captures it via `exception: e`.
    </rule>
    <rule enforcement="must_not">
      Never log request bodies or secrets — no free-text
      concatenation of params.
    </rule>
    <rule enforcement="should">
      Keep metrics tags low-cardinality (e.g., `form_version`,
      `stage`) — avoid exploding labels (e.g., per-`user_id`).
    </rule>
    <rule enforcement="verify">
      DataDog query: `@operation:create_claim` finds all matching
      logs
    </rule>
    <rule enforcement="verify">
      Exception backtrace preserved automatically via `exception:`
      key
    </rule>
    <rule enforcement="verify">
      Single log pattern (not 10,000 unique strings from
      interpolation)
    </rule>
    <rule enforcement="verify">
      Metrics tags stay below cardinality limits
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

  <default_to_action>
    When you detect an unstructured logging violation with high
    confidence, compose a PR comment that includes: 1. The
    specific violation (which logger call uses string
    interpolation or manual backtrace) 2. Why it matters
    (cardinality explosion, lost backtrace, unqueryable fields) 3.
    A concrete code suggestion replacing interpolation with
    keyword arguments and `exception: e` 4. The verification
    checklist items relevant to this specific case 5. A link to
    this play for full context Do not simply flag the violation --
    provide the fix. Show the exact refactored logger call with
    structured fields.
  </default_to_action>

  <verify>
    <command description="No string interpolation in logger calls in changed file">
      grep -On 'logger\.\w+\(".*#\{' {{file_path}} &amp;&amp; exit 1 || exit 0
    </command>
    <command description="No manual backtrace field in changed file">
      grep -On 'backtrace:\s*e\.backtrace' {{file_path}} &amp;&amp; exit 1 || exit 0
    </command>
    <command description="Run specs for changed file">
      bundle exec rspec {{spec_path}}
    </command>
    <command description="RuboCop passes for changed file">
      bundle exec rubocop {{file_path}}
    </command>
  </verify>

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

    [Play: Prefer structured logs](plays/prefer-structured-logs.md)
  </pr_comment_template>

  <anti_pattern_sources>
    <source name="String Interpolation Loses Structure" file="lib/pdf_fill/filler.rb:334" url="https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/lib/pdf_fill/filler.rb#L334" />
    <source name="Debug Prefix in Unstructured String" file="modules/vaos/app/services/vaos/v2/appointments_service.rb:90" url="https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/modules/vaos/app/services/vaos/v2/appointments_service.rb#L90" />
    <source name="Manual Backtrace Field Loses Exception Object" file="modules/vre/app/services/vre/ch31_eligibility/service.rb:38-42" url="https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/modules/vre/app/services/vre/ch31_eligibility/service.rb#L38-L42" />
  </anti_pattern_sources>

</agent_play>
-->

# Prefer structured logs; use Rails Semantic Logger exception handling

This play ensures all log output uses structured fields and Rails Semantic Logger's built-in exception handling, so every log entry is queryable, aggregatable, and retains full backtraces in DataDog.

> [!CAUTION]
> Unstructured logs with string interpolation cannot be queried by field, making debugging and alerting impossible.

## Why It Matters

When you use string interpolation in log messages, DataDog sees every unique interpolated value as a different log pattern. You cannot search by `file_path` or `error_code` because those values are buried in free text. When you log `e.message` instead of passing the full exception object via `exception: e`, you lose the backtrace and cause chain, so your team cannot find the failure location. A manual `backtrace: e.backtrace` field bypasses Semantic Logger's exception handling, losing the exception class and cause chain. Unstructured logs cannot be aggregated or alerted on -- DataDog sees 10,000 unique messages that are actually a single pattern.

## Guidance

Pass all dynamic values as keyword arguments to the logger, never as string interpolation. When logging exceptions, always use `exception: e` to let Rails Semantic Logger capture the exception class, message, backtrace, and cause chain in a single event. Keep log message strings static so DataDog can group them into patterns.

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

### Anti-Patterns from vets-api

#### String Interpolation Loses Structure

##### Anti-Pattern

[lib/pdf_fill/filler.rb:334](https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/lib/pdf_fill/filler.rb#L334)

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

##### Impact

Without structured logging:

- Cannot filter by `file_path` or error type in DataDog
- Log aggregators see every unique file path as a different message
- Exception backtrace is lost (only `e.message` captured)
- Every unique file path creates cardinality explosion

With structured logging:

- DataDog query: `@file_path:"/path/to/form.pdf"` finds all errors for that file
- Exception backtrace preserved automatically
- Single log pattern for all PDF stamping errors
- Can aggregate by error type, file path, or any structured field

---

#### Debug Prefix in Unstructured String

##### Anti-Pattern

[modules/vaos/app/services/vaos/v2/appointments_service.rb:90](https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/modules/vaos/app/services/vaos/v2/appointments_service.rb#L90)

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

##### Impact

Without structured logging:

- Cannot query "show all EPS debug logs"
- Cannot filter by `kept_facilities` count or `removed_facilities` list
- String concatenation makes automated parsing impossible
- Cannot generate metrics from facility counts

With structured logging:

- DataDog query: `@debug_category:eps` shows all EPS debug logs
- Can filter by `@kept_facilities` ranges or aggregate facility removal patterns
- Automated dashboards can track facility filtering metrics over time
- Can alert if `removed_facilities` exceeds threshold

---

#### Manual Backtrace Field Loses Exception Object

##### Anti-Pattern

[modules/vre/app/services/vre/ch31_eligibility/service.rb:38-42](https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/modules/vre/app/services/vre/ch31_eligibility/service.rb#L38-L42)

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

##### Impact

Without `exception:` key:

- `backtrace:` field loses exception class name (only shows stack trace array)
- Cause chain is lost (no visibility into wrapped exceptions)
- String interpolation of `message` creates cardinality explosion
- Semantic Logger's exception handling is bypassed

With `exception:` key:

- Semantic Logger automatically captures: exception class, message, backtrace, and cause chain
- APM can trace back through wrapped exceptions
- Single log pattern regardless of error message content
- No redundant backtrace logging (Semantic Logger handles it)

## Reference

### Structured Logging Pattern

```ruby
# Define safe fields to log
SAFE_LOG_FIELDS = %i[
  operation
  service
  application_id
  transaction_id
  form_version
  error_code
  status_code
  duration_ms
  request_id
  correlation_id
].freeze

def log_operation(action, context = {})
  safe_context = context.slice(*SAFE_LOG_FIELDS)

  Rails.logger.info(action, **safe_context)
end
```

### What to Log (Structured)

| Field | Purpose | Example |
|-------|---------|---------|
| `operation` | What action was attempted | `"create_claim"` |
| `service` | Which service/domain | `"claims"`, `"benefits"` |
| `application_id` | Safe business identifier | UUID |
| `error_code` | Stable error identifier | `"PAWS_DUPLICATE"` |
| `status` | HTTP status | `422` |
| `request_id` | Request correlation | UUID |
| `duration_ms` | Performance tracking | `1523` |
| `form_version` | Low-cardinality context | `"2025-v3"` |

## References

- [Rails Semantic Logger](https://logger.rocketjob.io/)
- [DataDog Log Management](https://docs.datadoghq.com/logs/)
