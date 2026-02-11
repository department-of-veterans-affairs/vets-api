---
id: respect-retry-headers
title: 'Retry smart: respect signals, fail fast, don''t spam logs'
version: 1
severity: HIGH
category: retry-resilience
tags:
- retry
- log-spam
- sidekiq
- retry-after
- circuit-breaker
- silent-failure
language: ruby
---

<!--
<agent_play>

  <context>
    A single timeout logs ERROR 16 times, drowning real issues in log
    spam and causing alert fatigue that pages on-call engineers for
    transient blips. Metrics show 16 failures for what is actually one
    job, making dashboards useless because you cannot tell a retry storm
    from an actual incident. A bare rescue in retry logic catches code
    bugs like typos, turning them into "transient timeouts" that loop
    infinitely and burn resources. When retries exhaust and the
    exception is swallowed, the method returns nil, the caller assumes
    success, and data is lost with zero visibility.
  </context>

  <applies_to>
    <glob>app/sidekiq/**/*.rb</glob>
    <glob>modules/*/app/sidekiq/**/*.rb</glob>
    <glob>config/initializers/**/*.rb</glob>
    <glob>app/services/**/*.rb</glob>
    <glob>modules/*/app/services/**/*.rb</glob>
    <glob>lib/**/*.rb</glob>
  </applies_to>

  <related_plays>
    <play id="send-retry-hints" relationship="complementary" />
    <play id="map-upstream-network-errors" relationship="complementary" />
  </related_plays>

  <retrieval_triggers>
    <trigger>logging ERROR on every Sidekiq retry attempt</trigger>
    <trigger>retry loop logs error 16 times for one failure</trigger>
    <trigger>bare rescue in retry logic catches code bugs</trigger>
    <trigger>retries exhaust silently and return nil</trigger>
    <trigger>missing Retry-After header on 429 response</trigger>
    <trigger>inflated failure metrics from retry counting</trigger>
  </retrieval_triggers>

  <detection>
    <pattern name="sidekiq_retry_with_error_logging" confidence="high">
      <signature>sidekiq_options\s+retry:\s*\d+</signature>
      <description>
        A Sidekiq job with retry enabled combined with `rescue` blocks
        that log ERROR or increment failure metrics on every attempt.
        The combination of `sidekiq_options retry: N` with
        `logger.error` in the same class means every transient retry
        produces an ERROR log entry and inflated failure metrics.
        Check the rescue block for `logger.error` or
        `StatsD.increment(...failure)`.
      </description>
      <example>sidekiq_options retry: 16` with `Rails.logger.error(...)` in rescue block</example>
      <example>sidekiq_options retry: 5` with `StatsD.increment("job.failure")` on every attempt</example>
    </pattern>
    <pattern name="bare_rescue_with_retry" confidence="medium">
      <signature>rescue\s*=>\s*e\n.*retry\b</signature>
      <description>
        A bare rescue (`rescue => e`) followed by a `retry` statement.
        Bare rescue catches everything including NameError,
        NoMethodError, and SignalException. This means typos and code
        bugs are retried as if they were transient network failures.
        Medium confidence because some retry helpers intentionally use
        broad rescue with a retry_on filter — read surrounding code to
        check.
      </description>
      <example>rescue =&gt; e\n  sleep delay\n  retry</example>
      <example>rescue =&gt; e\n  attempts += 1\n  retry if attempts &lt; max</example>
    </pattern>
    <pattern name="sleep_retry_without_exception_filter" confidence="medium">
      <signature>sleep\s+delay.*\n.*retry\b</signature>
      <description>
        A sleep-then-retry pattern without checking the exception
        type. This indicates a custom retry loop that does not
        distinguish transient failures from permanent ones. The retry
        will run for any exception including code bugs. Medium
        confidence because the exception check may occur earlier in
        the method.
      </description>
      <example>sleep delay if delay.positive?\n  retry</example>
      <example>sleep(2 ** attempt)\n  retry</example>
    </pattern>
    <heuristic>
      A Sidekiq job class that rescues all exceptions, calls a
      logging or metrics method, and then re-raises. If
      `sidekiq_options retry:` is set, Sidekiq will retry the job
      automatically — the rescue block fires on every attempt,
      producing N identical ERROR logs and N failure metric
      increments for a single job failure.
    </heuristic>
    <heuristic>
      A custom retry helper class or method that uses `rescue => e`
      (bare rescue) combined with `retry`. If the retry_on filter is
      nil or checks `e.message` with string matching, code bugs like
      NameError will be caught and retried because the error message
      won't match any filter, falling through to the silent failure
      path.
    </heuristic>
    <heuristic>
      A retry loop where retries exhaust without raising an
      exception. The method returns nil or an empty value. Callers
      assume success because no exception was raised. This is a data
      loss pattern — the operation silently failed.
    </heuristic>
    <false_positive>
      A Sidekiq job that uses `sidekiq_retries_exhausted` callback
      for ERROR logging and only logs WARN in the perform method's
      rescue block. This is the correct pattern — WARN for transient
      retries, ERROR only when retries are exhausted.
    </false_positive>
    <false_positive>
      A retry helper that catches specific exception classes (e.g.,
      `rescue Faraday::TimeoutError, Faraday::ConnectionFailed`)
      rather than bare rescue. Specific exception classes are
      acceptable for retry logic because they only catch transient
      network failures.
    </false_positive>
    <false_positive>
      A retry loop in test/spec code where broad rescue is used to
      test retry behavior. Test code intentionally exercises failure
      paths and should not be flagged.
    </false_positive>
  </detection>

  <rules>
    <rule enforcement="must">
      Only retry transient failures: 429, 503, 504,
      connection/timeout errors.
    </rule>
    <rule enforcement="must_not">
      Never retry client errors (4xx except 429) or server errors
      that indicate bugs (500 with code-level errors).
    </rule>
    <rule enforcement="must">
      Respect Retry-After headers from upstream — if the upstream
      sends it, honor it instead of guessing.
    </rule>
    <rule enforcement="must">
      Fail fast when circuit breaker is open or retry budget is
      exhausted — return immediately.
    </rule>
    <rule enforcement="must_not">
      Never log ERROR inside retry loops — log WARN for retry
      attempts, ERROR only when retries exhaust.
    </rule>
    <rule enforcement="should">
      Emit metrics for retry attempts separately from final
      failures.
    </rule>
    <rule enforcement="must_not">
      Never use bare rescue in retry logic — catch specific
      transient exception classes only.
    </rule>
    <rule enforcement="must">
      Re-raise the exception when retries exhaust — never silently
      return nil.
    </rule>
    <rule enforcement="verify">
      Single timeout -> Single ERROR log (not 16 identical entries)
    </rule>
    <rule enforcement="verify">
      Metrics track retry attempts vs final failures separately
    </rule>
    <rule enforcement="verify">
      Circuit breaker prevents retry storms when upstream degraded
    </rule>
    <rule enforcement="verify">
      Failed jobs raise exception (don't silently return nil)
    </rule>
  </rules>

  <investigate_before_answering>
    <step>Read the full class or method containing the retry logic to understand whether this is a Sidekiq job (managed retries) or custom retry code.</step>
    <step>Identify what exception types the called code can raise — check if the code calls upstream services (Faraday), databases, or internal methods.</step>
    <step>Determine whether the rescue block logs, emits metrics, or both on every attempt vs only on final failure.</step>
    <step>Check if `sidekiq_retries_exhausted` callback exists — if so, the ERROR logging may already be correctly placed.</step>
    <step>For custom retry helpers, check if the exception is re-raised when retries exhaust or silently swallowed (method returns nil).</step>
    <step>Verify whether a circuit breaker or Retry-After header is honored. Do not suggest removing retry logic entirely. The fix is to make retries smarter, not to eliminate them.</step>
  </investigate_before_answering>

  <severity_assessment>
    <critical>retry logic silently swallows exceptions and returns nil —
data loss risk</critical>
    <critical>bare rescue in retry loop catches code bugs (NameError,
NoMethodError) and retries them</critical>
    <high>Sidekiq job logs ERROR on every retry attempt — log spam and
alert fatigue</high>
    <high>failure metrics increment on every retry attempt — inflated
dashboard counts</high>
    <medium>missing Retry-After header on 429 response — clients retry
blindly</medium>
    <medium>fixed delay retry without exponential backoff or jitter</medium>
  </severity_assessment>

  <default_to_action>
    When you detect a retry-related violation with high
    confidence, compose a PR comment that includes: 1. The
    specific violation (log spam, bare rescue, silent swallowing,
    or missing Retry-After) 2. Why it matters (from
    context/why_it_matters — alert fatigue, inflated metrics, data
    loss, or thundering herd) 3. A concrete code suggestion from
    the golden patterns 4. The relevant reference (Sidekiq Error
    Handling wiki or RFC 7231) 5. A link to this play for full
    context Do not simply flag the violation — provide the fix.
    Include the specific code change needed (e.g., move ERROR to
    sidekiq_retries_exhausted, replace bare rescue with specific
    exception classes).
  </default_to_action>

  <verify>
    <command description="No ERROR logging inside retry loops">
      grep -On 'rescue.*\n.*retry\b' {{file_path}} | grep -i 'error' &amp;&amp; exit 1 || exit 0
    </command>
    <command description="No bare rescue with retry">
      grep -On 'rescue\s*=>\s*\w+\n.*retry\b' {{file_path}} &amp;&amp; exit 1 || exit 0
    </command>
    <command description="Run specs for changed file">
      bundle exec rspec {{spec_path}}
    </command>
    <command description="RuboCop passes for changed file">
      bundle exec rubocop {{file_path}}
    </command>
  </verify>

  <pr_comment_template>
    **Retry smart: respect signals, fail fast, don't spam logs** | `HIGH`

    `{{file_path}}:{{line_number}}` — {{one_line_violation_description}}

    **Why this matters:** {{why_it_matters_summary}}

    **Suggested fix:**
    ```ruby
    {{suggested_code}}
    ```

    **Verify:**
    - [ ] Single ERROR log per job failure (not per retry attempt)
    - [ ] Retry attempts logged at WARN with attempt context
    - [ ] Failure metrics increment once on final failure only
    - [ ] Specific exception classes in rescue (no bare rescue)
    - [ ] Exception re-raised when retries exhaust (no silent nil return)

    **References:**
    - [Sidekiq Error Handling](https://github.com/sidekiq/sidekiq/wiki/Error-Handling)
    - [RFC 7231 Retry-After](https://tools.ietf.org/html/rfc7231#section-7.1.3)

    [Play: Retry Smart](plays/respect-retry-headers-when-calling-upstream.md)
  </pr_comment_template>

  <anti_pattern_sources>
    <source name="Letter Ready Email Job" file="app/sidekiq/event_bus_gateway/letter_ready_email_job.rb" url="https://github.com/department-of-veterans-affairs/vets-api/blob/4ec33d9e1e4264476a01d77629068d182e2c6028/app/sidekiq/event_bus_gateway/letter_ready_email_job.rb" />
    <source name="Rack Attack Missing Retry-After" file="config/initializers/rack_attack.rb:68-79" url="https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/config/initializers/rack_attack.rb#L68-L79" />
    <source name="IVC CHAMPVA Retry Helper" file="modules/ivc_champva/app/services/ivc_champva/retry.rb" url="https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/ivc_champva/app/services/ivc_champva/retry.rb" />
  </anti_pattern_sources>

</agent_play>
-->

# Retry Smart: Respect Signals, Fail Fast, Don't Spam Logs

Retry logic is essential for resilience against transient failures, but poorly implemented retries create log spam, inflated metrics, and silent data loss. This play covers how to retry correctly.

> [!CAUTION]
> Logging ERROR on every retry attempt creates log spam that drowns real issues and inflates failure metrics.

## Why It Matters

When you log ERROR on every retry attempt, a single transient timeout generates 16 identical ERROR entries in a Sidekiq job with `retry: 16`. On-call engineers get paged for what is actually a self-recovering blip, and dashboards show 16 failures when only one job actually failed. Using bare rescue in retry logic is even worse — it catches code bugs like typos and NameError, turning them into infinite retry loops that burn resources. When retries exhaust and the exception is silently swallowed, the method returns nil, the caller assumes success, and data is lost with zero visibility.

## Guidance

Retry only transient failures (429, 503, 504, connection/timeout errors) using specific exception classes. Respect `Retry-After` headers from upstream services instead of guessing delays. Log WARN for retry attempts and reserve ERROR for when retries are fully exhausted. Always re-raise the exception when retries exhaust so callers know the operation failed.

### Do

- Only retry transient failures (429, 503, 504, connection/timeout errors):

  ```ruby
  rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
    attempt += 1
    retry if attempt < MAX_ATTEMPTS
    raise
  end
  ```

- Respect `Retry-After` headers from upstream:

  ```ruby
  if response.status == 429
    delay = response.headers["Retry-After"]&.to_i || default_delay
    sleep delay
    retry
  end
  ```

- Log WARN for retry attempts, ERROR only when retries exhaust:

  ```ruby
  rescue Faraday::TimeoutError => e
    attempt += 1
    if attempt < MAX_ATTEMPTS
      Rails.logger.warn("Retry attempt #{attempt}/#{MAX_ATTEMPTS}", error: e.class.name)
      retry
    end
    Rails.logger.error("Retries exhausted", error: e.class.name, attempts: attempt)
    raise
  end
  ```

- Re-raise the exception when retries exhaust:

  ```ruby
  # Sidekiq: use sidekiq_retries_exhausted for final ERROR logging
  sidekiq_retries_exhausted do |msg, ex|
    Rails.logger.error("Job permanently failed", job: msg["class"], error: ex.message)
  end
  ```

### Don't

- Retry client errors (4xx except 429) or code bugs (500):

  ```ruby
  # BAD — 404 will never succeed on retry
  rescue => e
    retry if attempts < 3
  end
  ```

- Log ERROR inside retry loops:

  ```ruby
  # BAD — 16 identical ERROR entries for one transient failure
  rescue => e
    Rails.logger.error("Job failed: #{e.message}")
    raise  # Sidekiq retries → logs ERROR again
  end
  ```

- Use bare rescue in retry logic:

  ```ruby
  # BAD — catches NameError, NoMethodError, typos
  rescue => e
    sleep delay
    retry
  end
  ```

- Let retries exhaust silently and return nil:

  ```ruby
  # BAD — caller thinks operation succeeded, data is lost
  rescue => e
    retry if attempts < max
    # Falls through, returns nil — NO exception raised
  end
  ```

## Anti-Patterns

### Letter Ready Email Job - Logging on Every Retry

#### Anti-Pattern

[app/sidekiq/event_bus_gateway/letter_ready_email_job.rb](https://github.com/department-of-veterans-affairs/vets-api/blob/4ec33d9e1e4264476a01d77629068d182e2c6028/app/sidekiq/event_bus_gateway/letter_ready_email_job.rb)

```ruby
class LetterReadyEmailJob
  include Sidekiq::Job

  sidekiq_options retry: 16  # Sidekiq will retry up to 16 times

  def perform(user_uuid)
    # ... email sending logic ...
  rescue => e
    record_email_send_failure(e)  # Called on EVERY retry attempt
    raise  # Re-raise to trigger Sidekiq retry
  end

  def record_email_send_failure(error)
    ::Rails.logger.error('LetterReadyEmailJob email error', { message: error.message })
    # Logs ERROR on every retry (16 times for one transient failure!)

    StatsD.increment("#{STATSD_METRIC_PREFIX}.failure")
    # Increments failure metric on every retry (inflates metrics)
  end
end
```

#### Golden Pattern

[lib/bgs/exceptions/bgs_errors.rb](https://github.com/department-of-veterans-affairs/vets-api/blob/4ec33d9e1e4264476a01d77629068d182e2c6028/lib/bgs/exceptions/bgs_errors.rb)

```ruby
def with_multiple_attempts_enabled
  attempt ||= 0
  yield
rescue => e
  attempt += 1
  if attempt < MAX_ATTEMPTS
    # WARN for retry attempts (transient failures expected)
    notify_of_service_exception(e, __method__.to_s, attempt, :warn)
    retry
  end
  # ERROR only on final failure (after all retries exhausted)
  notify_of_service_exception(e, __method__.to_s)
  raise
end
```

#### Impact

Without proper retry logging:

- **Log spam:** One transient network blip -> 16 identical ERROR log entries
- **Inflated metrics:** StatsD shows 16 failures when only 1 job actually failed
- **Alert fatigue:** On-call teams paged for transient issues that will self-recover
- **Can't distinguish:** "16 retries of 1 job" vs "16 different jobs failed"
- **Wrong log level:** Transient failures (expected) logged as ERROR (unexpected)
- **Debugging confusion:** Logs show "16 failures" but only 1 job in dead queue

With proper retry logging:

- **Clear signal:** WARN for transient retries, ERROR only for final failure
- **Accurate metrics:** 1 final failure = 1 metric increment
- **No alert spam:** Alerts fire only when retries exhausted (actual problem)
- **Debugging clarity:** Can see retry attempts (WARN) vs actual failures (ERROR)
- **Proper severity:** Transient issues don't trigger ERROR alerts

### Rack Attack - Missing Retry-After header for 429

> [!NOTE]
> This anti-pattern (Rack::Attack `throttled_responder` missing `Retry-After` header) is covered in detail in [Play 12: Send Retry Hints to Clients](13-send-retry-hints-to-clients.md#rack-attack-configuration), including the golden pattern and impact analysis.

---

### IVC CHAMPVA Retry Helper - Bare Rescue, Log Spam, and Silent Failure

#### Anti-Pattern

[modules/ivc_champva/app/services/ivc_champva/retry.rb](https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/ivc_champva/app/services/ivc_champva/retry.rb)

```ruby
module IvcChampva
  class Retry
    def self.do(max_retries = 3, delay = 1, retry_on: nil, on_failure: nil, &block)
      retry_on = Array(retry_on) if retry_on
      attempts = 0

      begin
        block.call
      rescue => e
        # VIOLATION 1: Bare rescue catches EVERYTHING (typos, signals, code bugs)
        on_failure&.call(e, attempts)

        if attempts < max_retries && (retry_on.nil? || retry_on.any? do |condition|
          e.message.downcase.include?(condition.downcase)
        end)
          attempts += 1
          Rails.logger.error "Retrying in #{delay} seconds..."
          # VIOLATION 2: Logs ERROR on EVERY retry (log spam)
          # VIOLATION 3: Wrong log level (ERROR for expected transient retry)
          # VIOLATION 4: No context - what failed? what exception? which attempt?

          sleep delay if delay.positive?
          retry
        end
        # VIOLATION 5: When retries exhausted, NO error log, NO exception raised
        # Exception is SILENTLY SWALLOWED - method returns nil
        # Calling code thinks operation succeeded → DATA LOSS
      end
    end
  end
end
```

#### Impact

Without proper retry implementation:

- **Bare rescue danger:** Typos like `ves_client.submit` caught and retried as if transient network issue
- **Log spam:** Single timeout -> `ERROR: Retrying in 0 seconds...` logged on every retry
- **Wrong severity:** ERROR for expected transient retries (should be WARN)
- **No context:** Can't tell WHAT operation failed, WHICH exception occurred, or WHY retry triggered
- **Silent exception swallowing:** When retries exhausted, NO error log, NO exception raised
  - Method returns `nil` instead of raising
  - Caller thinks operation succeeded
  - Controller returns 200 OK but operation actually failed
  - Database shows "submitted" but external system never received data
- **Data loss:** User sees "Form submitted successfully" but form never actually submitted to VES

With proper retry implementation (use Sidekiq job retry):

- **Specific exceptions:** Only catches `Faraday::TimeoutError`, `ConnectionFailed`
- **Single ERROR log:** One log when retries exhausted with full context
- **Correct severity:** WARN for transient retries, ERROR when exhausted
- **Rich context:** Operation name, attempt number, exception class, message
- **Fails loudly:** Re-raises exception so caller knows operation failed
- **No data loss:** Errors visible, operations fail properly, status tracking accurate

---

## Reference

### Quick Reference: What to Retry

| Error Type | Retry? | Why |
|------------|--------|-----|
| 429, 503, 504, timeouts | Yes | Transient (may succeed on retry) |
| 400, 401, 404, 422, 500 | No | Client error or bug (won't fix itself) |

## References

- [Sidekiq Error Handling](https://github.com/sidekiq/sidekiq/wiki/Error-Handling)
- [RFC 7231 Retry-After](https://tools.ietf.org/html/rfc7231#section-7.1.3)
