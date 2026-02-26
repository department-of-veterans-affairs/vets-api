---
id: respect-retry-headers
title: 'Retry smart: respect signals, fail fast, don''t spam logs'
severity: HIGH
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

    [Play: Retry Smart](21-respect-retry-headers-when-calling-upstream.md)
  </pr_comment_template>

</agent_play>
-->

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

### IVC CHAMPVA Retry Helper - Bare Rescue, Log Spam, and Silent Failure

#### Anti-Pattern

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
