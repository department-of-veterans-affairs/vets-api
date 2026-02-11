---
id: expected-vs-unexpected
title: Expected vs Unexpected Errors (Logging + APM)
version: 2
severity: CRITICAL
category: observability
tags:
- expected-errors
- unexpected-errors
- apm
- span-set-error
- log-levels
- alert-fatigue
language: ruby
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

  <retrieval_triggers>
    <trigger>span.set_error called for all exceptions including 4xx</trigger>
    <trigger>APM flooded with validation errors and 422s</trigger>
    <trigger>expected errors logged as ERROR instead of WARN</trigger>
    <trigger>alert fatigue from client validation failures</trigger>
    <trigger>ExceptionHandling marks 4xx as APM errors</trigger>
    <trigger>SLI error rate includes client mistakes</trigger>
  </retrieval_triggers>

  <detection>
    <pattern name="set_error_without_status_check" confidence="high">
      <signature>set_error\(</signature>
      <description>
        Calls `set_error` on a Datadog span without first checking the
        HTTP status code. In the ExceptionHandling concern, this marks
        ALL exceptions (including expected 4xx errors) as APM errors,
        flooding dashboards with validation failures.
      </description>
      <example>Datadog::Tracing.active_span&amp;.set_error(exception)</example>
      <example>span&amp;.set_error(exception)</example>
    </pattern>
    <pattern name="span_set_error_in_controller" confidence="high">
      <signature>span\.set_error</signature>
      <description>
        Calls `span.set_error` directly in a controller (not in
        ExceptionHandling concern). Controllers should validate and
        throw; the ExceptionHandling concern decides whether to mark
        spans as errors based on status code. Manual span tagging in
        controllers violates layering and often tags expected errors
        as APM errors.
      </description>
      <example>span.set_error(e)` in a controller rescue block</example>
      <example>Datadog::Tracing.active_span&amp;.set_error(e)` in a controller</example>
    </pattern>
    <pattern name="span_set_tag_error_in_rescue" confidence="medium">
      <signature>span\.set_tag.*error</signature>
      <description>
        Manually sets error-related tags on a Datadog span inside a
        rescue block. This typically indicates a controller is doing
        APM tagging that should be handled centrally by
        ExceptionHandling. Medium confidence because some legitimate
        instrumentation may use error tags in non-rescue contexts.
      </description>
      <example>span.set_tag('error.type', 'record_invalid')</example>
      <example>span.set_tag('error.specific_reason', 'timeout')</example>
    </pattern>
    <heuristic>
      A `rescue_from` handler or `report_mapped_exception` method
      that calls `set_error` without checking whether the mapped
      status code is >= 500 is a strong signal. The
      ExceptionHandling concern processes ALL exceptions through the
      same path, so missing a status check means every 4xx becomes
      an APM error.
    </heuristic>
    <heuristic>
      A controller rescue block that sets Datadog span tags
      (`error.type`, `error.specific_reason`) before re-raising to
      ExceptionHandling indicates manual span tagging that violates
      layering. The controller should only validate and throw; APM
      classification belongs in the centralized concern.
    </heuristic>
    <false_positive>
      `span.set_error` called inside a conditional that checks
      `status_code >= 500` is correct behavior. This is the golden
      pattern — only unexpected errors are marked as APM errors. Do
      not flag if the status check is present.
    </false_positive>
    <false_positive>
      `span.set_tag` used for non-error metadata (e.g.,
      `span.set_tag('service.name', ...)` or
      `span.set_tag('request.id', ...)`) is legitimate
      instrumentation. Only flag when error-related tags are set in
      rescue blocks without status code checks.
    </false_positive>
  </detection>

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

  <default_to_action>
    When you detect a violation with high confidence, compose a PR
    comment that includes: 1. The specific violation (set_error
    without status check, or manual span tagging in controller) 2.
    Why it matters (APM flooded with 4xx, on-call paged for
    validation errors, SLI broken) 3. A concrete code suggestion:
    for ExceptionHandling, add the `if va_exception.status_code >=
    500` guard; for controllers, remove manual span tagging and
    ensure re-raise to ExceptionHandling 4. The Error Code Paradox
    warning about monitoring 4xx spikes 5. A link to this play Do
    not simply flag the violation -- provide the complete fix. The
    ExceptionHandling fix is a single conditional wrapping the
    existing set_error calls.
  </default_to_action>

  <verify>
    <command description="No unconditional set_error in ExceptionHandling">
      grep -On 'set_error\(' app/controllers/concerns/exception_handling.rb | grep -v 'status_code.*>=.*500' | grep -v '#' &amp;&amp; exit 1 || exit 0
    </command>
    <command description="No manual span.set_error in controllers">
      grep -rn 'span.*set_error\|set_tag.*error' app/controllers/ modules/*/app/controllers/ --include='*.rb' | grep -v exception_handling | grep -v '#' &amp;&amp; exit 1 || exit 0
    </command>
    <command description="Run specs for ExceptionHandling">
      bundle exec rspec spec/controllers/concerns/exception_handling_spec.rb
    </command>
    <command description="RuboCop passes for ExceptionHandling">
      bundle exec rubocop app/controllers/concerns/exception_handling.rb
    </command>
  </verify>

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

    [Play: Expected vs Unexpected Errors](plays/expected-vs-unexpected-errors.md)
  </pr_comment_template>

</agent_play>
-->

# Expected vs Unexpected Errors (Logging + APM)

Not all errors deserve the same treatment. This play explains how to classify errors by expectedness so your APM dashboards, alerts, and SLIs reflect actual system health instead of drowning in noise.

> [!CAUTION]
> Calling `span.set_error(exception)` marks a span as an error in APM. If applied to expected errors (like 4xx), it pollutes error tracking dashboards, triggers false alerts, and buries real issues under thousands of expected business outcomes.

## Why It Matters

Your APM shows 10,000 errors, but 9,500 are 422 validation failures and only 500 are real server errors -- genuine issues are buried in noise. When Rails logs validation failures at ERROR level, it fires alerts and pages on-call engineers for user typos rather than system failures, causing alert fatigue. Your dashboard reads "Error Rate 95%" when the system is actually fine, because client mistakes inflate the metric and break the SLI. ExceptionHandling marks most exceptions as APM errors without distinguishing expected 4xx from unexpected 5xx, because the `skip_sentry_exception?` check only filters a narrow list of known exceptions.

## Guidance

The correct approach is to classify errors by expectedness at the centralized ExceptionHandling layer: log expected errors (4xx) as WARN without marking APM spans, and log unexpected errors (5xx) as ERROR with `span.set_error`. Controllers should only validate and throw -- never manually tag spans.

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

**Execution Flow for Validation Error:**

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

**Critical Issue**: `report_mapped_exception` in [exception_handling.rb:103-104](https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/app/controllers/concerns/exception_handling.rb#L103-L104) calls `span.set_error` for **every exception**, regardless of whether it's expected (4xx) or unexpected (5xx).

---

### ExceptionHandling set_error Issue

#### Anti-Pattern

[app/controllers/concerns/exception_handling.rb:103-104](https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/app/controllers/concerns/exception_handling.rb#L103-L104)

```ruby
def report_mapped_exception(exception, va_exception)
  # ... logging to Sentry and Rails (lines 87-95) ...

  # Calls set_error for ALL exceptions including expected errors
  Datadog::Tracing.active_span&.set_error(exception)
  request.env[Datadog::Tracing::Contrib::Rack::Ext::RACK_ENV_REQUEST_SPAN]&.set_error(exception)
end
```


**Violations:**
- Calls `set_error` for ALL exceptions regardless of status code (4xx and 5xx alike)
- 422 Validation Errors marked as APM errors (wrong -- expected business outcome)
- 404 Not Found marked as APM errors (wrong -- expected business outcome)
- 403 Forbidden marked as APM errors (wrong -- expected business outcome)
- APM dashboards flooded with validation failures that are expected business outcomes
- Cannot distinguish real system failures (5xx) from expected client errors (4xx)
- False alerts wake on-call for "user entered invalid email"
- Real 500s buried under thousands of 422s

#### Golden Pattern

**How It Should Work:**

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


**Improvements:**
- Checks `va_exception.status_code >= 500` before calling `set_error`
- Expected errors (4xx) logged as WARN, not marked as APM errors
- Unexpected errors (5xx) logged as ERROR, marked as APM errors
- APM dashboards show only real system failures
- SLI error rate reflects actual system health (5xx only)
- On-call only paged for system failures, not validation errors

#### Impact

**Without the fix:**
- APM dashboards flooded with validation failures (expected business outcomes)
- Cannot distinguish real system failures from expected business errors
- False alerts wake on-call for "user entered invalid email"
- Real 500s buried under thousands of 422s

**With the fix:**
- APM dashboards show only real system failures (5xx)
- On-call only paged for system failures, not validation errors
- SLI error rate reflects actual system health

---

### Manual Span Tagging

#### Anti-Pattern

[modules/accredited_representative_portal/.../representative_form_upload_controller.rb:46-51](https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/modules/accredited_representative_portal/app/controllers/accredited_representative_portal/v0/representative_form_upload_controller.rb#L46-L51)

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


**Violations:**
- Violates layering: Controller validates (correct), but also does APM tagging (should be in ExceptionHandling)
- Validation errors (422) are expected, shouldn't be tagged as APM errors
- Duplicates responsibility: ExceptionHandling will also process this exception
- Creates inconsistency: some controllers tag spans, some don't

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


**Improvements:**
- Controller only validates and throws -- no APM tagging responsibility
- ExceptionHandling decides logging level and APM treatment centrally
- No duplicate span tagging between controller and concern
- Consistent behavior across all controllers

#### Impact

**Without the fix:**
- APM dashboards flooded with validation failures (expected business outcomes)
- Cannot distinguish real system failures from expected business errors
- False alerts wake on-call for "user entered invalid email"
- Real 500s buried under thousands of 422s
- Controllers inconsistently tag spans -- some do, some don't

**With the fix:**
- APM dashboards show only real system failures (5xx)
- On-call only paged for system failures, not validation errors
- SLI error rate reflects actual system health
- Controllers only validate and throw -- consistent behavior

---

### Best Practice Examples from vets-api

> **Note:** The codebase generally follows good practices for log levels. Below are representative examples showing correct usage.

**WARN for expected failures (4xx):**

[lib/dependents/monitor.rb:68-72](https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/lib/dependents/monitor.rb#L68-L72)

```ruby
rescue => e
  Rails.logger.warn('Unable to find claim', { claim_id:, e: })
  # WARN: Expected — claim might not exist, not a system error
  nil
end
```

**WARN for transient, ERROR when exhausted:**

[lib/debt_management_center/sharepoint/request.rb:231-247](https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/lib/debt_management_center/sharepoint/request.rb#L231-L247)

```ruby
if attempts < max_attempts
  Rails.logger.warn("#{operation_name} failed, retrying...")  # Transient = warn
  retry
else
  Rails.logger.error("#{operation_name} failed after #{attempts} attempts")  # Persistent = error
  raise
end
```

**ERROR for unexpected failures (5xx):**

[lib/dependents/monitor.rb:115-116](https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/lib/dependents/monitor.rb#L115-L116)

```ruby
rescue => e
  Rails.logger.error(message, payload)  # ERROR: Unexpected system failure
end
```

## Reference

### Expected vs Unexpected: Transport-Agnostic

The principle applies across protocols:

| Protocol | Expected Errors | Unexpected Errors |
|----------|----------------|-------------------|
| **HTTP** | 4xx (client errors) | 5xx (server errors) |
| **Direct Service Calls** | ValidationError, NotFoundError, UnauthorizedError | ConnectionError, TimeoutError, SystemError, bugs |
| **GraphQL** | Errors in `errors` array | 500 response, timeout, connection failure |
| **gRPC** | `INVALID_ARGUMENT`, `NOT_FOUND`, `PERMISSION_DENIED` | `INTERNAL`, `UNAVAILABLE`, `DEADLINE_EXCEEDED` |

**Examples of Expected vs Unexpected:**

| Scenario | Expected? | Log Level | span.set_error? |
|----------|-----------|-----------|----------------|
| User enters invalid email format | Expected | `warn` | No |
| User submits form with missing field | Expected | `warn` | No |
| User lacks permission | Expected | `warn` | No |
| Requested resource doesn't exist | Expected | `warn` | No |
| Database deadlock during write | Unexpected | `error` | Yes |
| Upstream service timeout | Unexpected | `error` | Yes |
| Code bug (NoMethodError) | Unexpected | `error` | Yes |

### The Error Code Paradox

> [!WARNING]
> **Why "Correct" 4xx Status Codes Need Monitoring**
>
> Fixing RuntimeErrors to return proper 4xx status codes (instead of 500) is crucial, but it creates a hidden danger: **validation bugs can go undetected** if you don't monitor 4xx spike patterns.

**Example Scenario:**

```ruby
# Developer accidentally breaks SSN validation (9 digits -> 8 digits)
def validate_ssn(ssn)
  if ssn.length != 8  # BUG: Should be 9!
    raise Common::Exceptions::ValidationError.new('Invalid SSN')
  end
end
```

**What happens:**

- Returns HTTP 422 Unprocessable Entity (correct status code)
- Uses typed exception ValidationError (not RuntimeError)
- **NO ALERTS** -- 422s are classified as "expected user errors"
- **ALL valid SSNs rejected** but no monitoring system detects the spike

**The Paradox:**

- If this was a RuntimeError -> 500 alerts fire immediately
- With "correct" 422 -> no alerts -> bug discovered via user reports

**The Solution:**

Monitor for abnormal 4xx patterns:

```ruby
# Alert on baseline anomalies
if four_xx_errors_per_minute > baseline * 3
  alert("Unusual spike in 422 errors - possible validation bug")
end
```

**Key Insight**: A validation bug returning "correct" 422s is MORE dangerous than one returning 500s, because 500s trigger alerts while 422s can fly under the radar. Always pair correct error classification with anomaly detection.

### Quick Reference

| HTTP Status | Log Level | span.set_error? | Alert? | Example |
|-------------|-----------|----------------|--------|---------|
| **4xx (400-429)** | `warn` | No | No* | Client error, expected |
| **5xx (500-504)** | `error` | Yes | Yes | Server error, unexpected |

\* But monitor for spike patterns (baseline x 3 anomaly)

## References

- [Datadog APM Traces](https://docs.datadoghq.com/tracing/)
