---
id: expected-vs-unexpected
title: Expected vs Unexpected Errors (Logging + APM)
severity: CRITICAL
---

<!--
<agent_play>

  <context>
    APM shows 10,000 errors, but 9,500 are 422 validation failures and
    only 500 are real server errors, burying genuine issues in noise.
    Rails logs validation failures at ERROR level, firing alerts and
    paging on-call engineers for user typos rather than system failures,
    which causes alert fatigue. The dashboard reads "Error Rate 95%"
    when the system is actually fine, because client mistakes inflate
    the metric and break the SLI. ExceptionHandling marks most
    exceptions as APM errors without distinguishing expected 4xx from
    unexpected 5xx, because the skip_sentry_exception? check only
    filters a narrow list of known exceptions.
  </context>

  <applies_to>
    <glob>app/controllers/concerns/exception_handling.rb</glob>
    <glob>app/controllers/**/*.rb</glob>
    <glob>modules/*/app/controllers/**/*.rb</glob>
  </applies_to>

  <related_plays>
    <play id="classify-errors" relationship="prerequisite" />
    <play id="prefer-structured-logs" relationship="complementary" />
    <play id="dont-build-module-frameworks" relationship="complementary" />
  </related_plays>

  <rules>
    <rule enforcement="must">
      Log expected errors (4xx) as WARN and do NOT call
      span.set_error — they are normal business outcomes.
    </rule>
    <rule enforcement="must">
      Log unexpected errors (5xx) as ERROR and call span.set_error —
      they need investigation.
    </rule>
    <rule enforcement="must">
      ExceptionHandling must check va_exception.status_code >= 500
      before calling span.set_error.
    </rule>
    <rule enforcement="must_not">
      Never call span.set_error for 4xx exceptions — this floods APM
      with expected business outcomes.
    </rule>
    <rule enforcement="must_not">
      Never manually tag spans with error metadata in controllers —
      let ExceptionHandling decide.
    </rule>
    <rule enforcement="should">
      Monitor 4xx spike patterns (baseline x 3 anomaly detection) to
      catch validation bugs that return "correct" 422s.
    </rule>
    <rule enforcement="verify">
      ExceptionHandling checks `status >= 500` before calling
      `span.set_error`
    </rule>
    <rule enforcement="verify">
      APM error rate reflects only 5xx (system failures, not client
      mistakes)
    </rule>
    <rule enforcement="verify">
      Validation errors (422) logged as WARN, NOT in APM error
      dashboards
    </rule>
    <rule enforcement="verify">
      Alerts fire only for unexpected failures (bugs, timeouts,
      infrastructure)
    </rule>
    <rule enforcement="verify">
      Log level matches expectedness, not just status code
    </rule>
    <rule enforcement="verify">
      SLI measures system health (5xx) not client behavior (4xx)
    </rule>
    <rule enforcement="verify">
      Baseline 4xx rates documented and monitored for anomalies
    </rule>
  </rules>

  <investigate_before_answering>
    <step>Read `app/controllers/concerns/exception_handling.rb` fully, especially the `report_mapped_exception` method, to understand the current flow from exception to APM span tagging.</step>
    <step>Identify whether `va_exception.status_code` is available in the method scope. The fix depends on being able to check the status code before calling `set_error`.</step>
    <step>Check if the violation is in ExceptionHandling (centralized fix) or in a specific controller (remove manual span tagging, let ExceptionHandling decide).</step>
    <step>If in a controller, check whether the controller manually tags spans AND re-raises to ExceptionHandling. If so, the fix is to remove manual tagging, not to add status checks in the controller.</step>
    <step>Verify whether the controller's exception will flow to ExceptionHandling. If the controller catches and does not re-raise, that is a separate issue (see Play: Don't Swallow Errors). Do not suggest adding status checks to individual controllers. The fix belongs in ExceptionHandling, which is the single point of responsibility for APM error classification.</step>
  </investigate_before_answering>

  <severity_assessment>
    <critical>set_error called for all exceptions in ExceptionHandling
concern (affects entire application)</critical>
    <critical>APM error rate includes 4xx client errors making SLI metrics
useless</critical>
    <high>manual span.set_error in controller rescue block for expected
error types</high>
    <high>manual span.set_tag with error metadata in controller
(violates layering)</high>
    <medium>Rails.logger.error used for 4xx validation failures (should be
warn)</medium>
  </severity_assessment>

  <pr_comment_template>
    **Expected vs Unexpected Errors (Logging + APM)** | `CRITICAL`

    `{{file_path}}:{{line_number}}` -- {{one_line_violation_description}}

    **Why this matters:** Calling `span.set_error` for expected errors (4xx) floods
    APM with validation failures. On-call gets paged for "user entered invalid email."
    Real 500s are buried under thousands of 422s. SLI error rate shows 95% when the
    system is healthy.

    **The Rule:**
    - Expected errors (4xx) -> `Rails.logger.warn` + NO `span.set_error`
    - Unexpected errors (5xx) -> `Rails.logger.error` + YES `span.set_error`

    **Suggested fix:**
    ```ruby
    {{suggested_code}}
    ```

    **Verify:**
    - [ ] `span.set_error` called only when `status_code >= 500`
    - [ ] 4xx validation errors logged as WARN, not marked as APM errors
    - [ ] No manual span tagging in controllers
    - [ ] APM error rate reflects only 5xx system failures
    - [ ] 4xx spike monitoring in place (Error Code Paradox)

    [Play: Expected vs Unexpected Errors](09-expected-vs-unexpected-errors.md)
  </pr_comment_template>

</agent_play>
-->

### Do

- Log expected errors (4xx) as WARN -- they are normal business outcomes:
  ```ruby
  Rails.logger.warn('Validation failed', { status: 422, message: exception.message })
  ```
- Log unexpected errors (5xx) as ERROR and call `span.set_error`:
  ```ruby
  if va_exception.status_code >= 500
    Datadog::Tracing.active_span&.set_error(exception)
  end
  ```
- Check `va_exception.status_code >= 500` before calling `span.set_error` in ExceptionHandling
- Monitor 4xx spike patterns for anomaly detection (baseline x 3)

### Don't

- Call `span.set_error` for 4xx exceptions -- this floods APM with expected business outcomes
- Manually tag spans with error metadata in controllers -- let ExceptionHandling decide:
  ```ruby
  # BAD -- controller doing APM tagging that belongs in ExceptionHandling
  span.set_tag('error.type', 'record_invalid')
  span.set_tag('error.specific_reason', 'record_invalid')
  ```

## Anti-Patterns

### The Problem Today: ExceptionHandling Floods APM

```
1. Controller action (e.g., FormsController#create)
   |-> Validates params
       |-> Raises Common::Exceptions::ValidationErrors (422)
           |
2. ExceptionHandling concern intercepts (rescue_from 'Exception')
   |-> Maps to va_exception
       |-> Calls report_mapped_exception(exception, va_exception)
           |-> Logs to Rails
           |-> ALWAYS calls span.set_error(exception) <-- THE PROBLEM
               |-> Marks APM span as error (even though 422 is expected)
```

### ExceptionHandling set_error Issue

#### Anti-Pattern

```ruby
def report_mapped_exception(exception, va_exception)
  # ... logging to Sentry and Rails (lines 87-95) ...

  # Calls set_error for ALL exceptions including expected errors
  Datadog::Tracing.active_span&.set_error(exception)
  request.env[Datadog::Tracing::Contrib::Rack::Ext::RACK_ENV_REQUEST_SPAN]&.set_error(exception)
end
```

#### Golden Pattern

```
Validation Error (422) - Expected:
1. Controller action raises Common::Exceptions::ValidationErrors (422)
   |
2. ExceptionHandling concern intercepts
   |-> Maps to va_exception
       |-> Logs to Rails (WARN level)
       |-> Checks: va_exception.status_code >= 500? -> NO (422 < 500)
           |-> SKIPS span.set_error
               |-> APM dashboard shows NO error

System Error (500) - Unexpected:
1. Service encounters database timeout, raises error
   |
2. ExceptionHandling concern intercepts
   |-> Maps to Common::Exceptions::InternalServerError (500)
       |-> Logs to Rails (ERROR level)
       |-> Logs to Sentry
       |-> Checks: va_exception.status_code >= 500? -> YES (500 >= 500)
           |-> Calls span.set_error(exception)
               |-> APM dashboard shows error (needs investigation)
```

**Code Implementation:**

```ruby
def report_mapped_exception(exception, va_exception)
  # Determine log level based on expectedness
  log_level = va_exception.status_code >= 500 ? :error : :warn

  # Log to Rails at appropriate level
  Rails.logger.public_send(log_level, 'Exception occurred', {
    exception: exception.class.name,
    message: exception.message,
    status: va_exception.status_code
  })

  # Log to Sentry only for unexpected errors
  Raven.capture_exception(exception) if va_exception.status_code >= 500

  # Only mark unexpected failures as APM errors (5xx)
  if va_exception.status_code >= 500
    Datadog::Tracing.active_span&.set_error(exception)
    request.env[Datadog::Tracing::Contrib::Rack::Ext::RACK_ENV_REQUEST_SPAN]&.set_error(exception)
  end
  # Expected errors (4xx) are logged as WARN but NOT marked as APM errors
end
```

### Manual Span Tagging

#### Anti-Pattern

```ruby
rescue service::RecordInvalidError => e
  span = Datadog::Tracing.active_span
  span.set_tag('error.type', 'record_invalid')
  span.set_tag('error.specific_reason', 'record_invalid')  # Manual tagging
  span.set_tag('error.original_class', e.class.name)
  raise Common::Exceptions::ValidationErrors, e.record
  # Re-raises to ExceptionHandling ✓
  # But manually tags span before re-raising ✗
end
```

#### Golden Pattern

```ruby
# Just validate and throw (no rescue, no span tagging)
def upload
  form = service.create_form(params)
  # If validation fails, service raises Common::Exceptions::ValidationErrors
  # ExceptionHandling catches it, logs WARN, returns 422, does NOT call span.set_error
  render json: form, status: :created
end
```

