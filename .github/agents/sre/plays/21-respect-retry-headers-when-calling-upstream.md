# Play 21: Retry Smart: Respect Signals, Fail Fast, Don't Spam Logs

## Context
A single timeout logs ERROR 16 times, drowning real issues in log spam and causing alert fatigue that pages on-call engineers for transient blips. Metrics show 16 failures for what is actually one job, making dashboards useless because you cannot tell a retry storm from an actual incident. A bare rescue in retry logic catches code bugs like typos, turning them into "transient timeouts" that loop infinitely and burn resources. When retries exhaust and the exception is swallowed, the method returns nil, the caller assumes success, and data is lost with zero visibility.

## Applies To
- `app/sidekiq/**/*.rb`
- `modules/*/app/sidekiq/**/*.rb`
- `config/initializers/**/*.rb`
- `app/services/**/*.rb`
- `modules/*/app/services/**/*.rb`
- `lib/**/*.rb`

## Investigation Steps
1. Read the full class or method containing the retry logic to understand whether this is a Sidekiq job (managed retries) or custom retry code.
2. Identify what exception types the called code can raise -- check if the code calls upstream services (Faraday), databases, or internal methods.
3. Determine whether the rescue block logs, emits metrics, or both on every attempt vs only on final failure.
4. Check if `sidekiq_retries_exhausted` callback exists -- if so, the ERROR logging may already be correctly placed.
5. For custom retry helpers, check if the exception is re-raised when retries exhaust or silently swallowed (method returns nil).
6. Verify whether a circuit breaker or Retry-After header is honored. Do not suggest removing retry logic entirely. The fix is to make retries smarter, not to eliminate them.

## Severity Assessment
- **CRITICAL:** Retry logic silently swallows exceptions and returns nil -- data loss risk
- **CRITICAL:** Bare rescue in retry loop catches code bugs (NameError, NoMethodError) and retries them
- **HIGH:** Sidekiq job logs ERROR on every retry attempt -- log spam and alert fatigue
- **HIGH:** Failure metrics increment on every retry attempt -- inflated dashboard counts
- **MEDIUM:** Missing Retry-After header on 429 response -- clients retry blindly
- **MEDIUM:** Fixed delay retry without exponential backoff or jitter

## Golden Patterns

### Do
Only retry transient failures (429, 503, 504, connection/timeout errors):
```ruby
rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
  attempt += 1
  retry if attempt < MAX_ATTEMPTS
  raise
end
```

Respect `Retry-After` headers from upstream:
```ruby
if response.status == 429
  delay = response.headers["Retry-After"]&.to_i || default_delay
  sleep delay
  retry
end
```

Log WARN for retry attempts, ERROR only when retries exhaust:
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

Use `sidekiq_retries_exhausted` for final ERROR logging in Sidekiq jobs:
```ruby
sidekiq_retries_exhausted do |msg, ex|
  Rails.logger.error("Job permanently failed", job: msg["class"], error: ex.message)
end
```

### Don't
Retry client errors (4xx except 429) or code bugs (500):
```ruby
# BAD -- 404 will never succeed on retry
rescue => e
  retry if attempts < 3
end
```

Log ERROR inside retry loops:
```ruby
# BAD -- 16 identical ERROR entries for one transient failure
rescue => e
  Rails.logger.error("Job failed: #{e.message}")
  raise  # Sidekiq retries -> logs ERROR again
end
```

Use bare rescue in retry logic:
```ruby
# BAD -- catches NameError, NoMethodError, typos
rescue => e
  sleep delay
  retry
end
```

Let retries exhaust silently and return nil:
```ruby
# BAD -- caller thinks operation succeeded, data is lost
rescue => e
  retry if attempts < max
  # Falls through, returns nil -- NO exception raised
end
```

## Anti-Patterns

### Letter Ready Email Job - Logging on Every Retry
**Anti-pattern:**
```ruby
class LetterReadyEmailJob
  include Sidekiq::Job

  sidekiq_options retry: 16

  def perform(user_uuid)
    # ... email sending logic ...
  rescue => e
    record_email_send_failure(e)  # Called on EVERY retry attempt
    raise
  end

  def record_email_send_failure(error)
    ::Rails.logger.error('LetterReadyEmailJob email error', { message: error.message })
    StatsD.increment("#{STATSD_METRIC_PREFIX}.failure")
  end
end
```
**Problem:** One transient network blip produces 16 identical ERROR log entries. StatsD shows 16 failures when only 1 job actually failed. On-call teams paged for transient issues that will self-recover. Cannot distinguish "16 retries of 1 job" vs "16 different jobs failed."

**Corrected:**
```ruby
def with_multiple_attempts_enabled
  attempt ||= 0
  yield
rescue => e
  attempt += 1
  if attempt < MAX_ATTEMPTS
    notify_of_service_exception(e, __method__.to_s, attempt, :warn)
    retry
  end
  notify_of_service_exception(e, __method__.to_s)
  raise
end
```

### IVC CHAMPVA Retry Helper - Bare Rescue, Log Spam, and Silent Failure
**Anti-pattern:**
```ruby
module IvcChampva
  class Retry
    def self.do(max_retries = 3, delay = 1, retry_on: nil, on_failure: nil, &block)
      retry_on = Array(retry_on) if retry_on
      attempts = 0

      begin
        block.call
      rescue => e
        on_failure&.call(e, attempts)

        if attempts < max_retries && (retry_on.nil? || retry_on.any? do |condition|
          e.message.downcase.include?(condition.downcase)
        end)
          attempts += 1
          Rails.logger.error "Retrying in #{delay} seconds..."
          sleep delay if delay.positive?
          retry
        end
        # When retries exhausted, NO error log, NO exception raised
        # Exception is SILENTLY SWALLOWED - method returns nil
      end
    end
  end
end
```
**Problem:** Bare rescue catches EVERYTHING (typos, signals, code bugs). Logs ERROR on EVERY retry (log spam). Wrong log level (ERROR for expected transient retry). No context -- what failed? what exception? which attempt? When retries exhausted, NO exception raised -- method returns nil. Caller thinks operation succeeded, leading to data loss.

**Corrected:** Use Sidekiq job retry with specific exception classes, WARN for transient retries, ERROR when exhausted, and always re-raise the exception.

## Finding Template
**Retry smart: respect signals, fail fast, don't spam logs** | `HIGH`

`{{file_path}}:{{line_number}}` -- {{one_line_violation_description}}

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

## Verify Commands
```bash
# No ERROR logging inside retry loops
grep -On 'rescue.*\n.*retry\b' {{file_path}} | grep -i 'error' && exit 1 || exit 0

# No bare rescue with retry
grep -On 'rescue\s*=>\s*\w+\n.*retry\b' {{file_path}} && exit 1 || exit 0

# Run specs for changed file
bundle exec rspec {{spec_path}}

# RuboCop passes for changed file
bundle exec rubocop {{file_path}}
```

## Related Plays
- Play: send-retry-hints (complementary)
- Play: map-upstream-network-errors (complementary)
