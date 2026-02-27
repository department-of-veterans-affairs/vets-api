---
id: dont-swallow-errors
title: Don't swallow errors (retries, fallbacks, silent returns)
severity: HIGH
---

<!--
<agent_play>

  <context>
    A BGS timeout that returns nil looks like "no file number found,"
    when in reality the upstream service timed out and there is no way
    to distinguish the two. A bare rescue that swallows a NoMethodError
    and returns false makes the caller think "access denied," when it is
    actually a code bug. When retries exhaust silently and the method
    returns nil, the caller assumes success, data is never submitted,
    and there is zero visibility into the failure. APM sees nothing
    because errors are swallowed before telemetry fires, so debugging
    requires manual log analysis that wastes hours.
  </context>

  <applies_to>
    <glob>app/controllers/**/*.rb</glob>
    <glob>app/sidekiq/**/*.rb</glob>
    <glob>app/models/**/*.rb</glob>
    <glob>modules/*/app/controllers/**/*.rb</glob>
    <glob>modules/*/app/models/**/*.rb</glob>
    <glob>modules/*/app/sidekiq/**/*.rb</glob>
    <glob>lib/**/*.rb</glob>
  </applies_to>

  <related_plays>
    <play id="bare-rescue" relationship="prerequisite" />
    <play id="preserve-cause-chains" relationship="complementary" />
  </related_plays>

  <rules>
    <rule enforcement="must">
      Raise a typed exception from `Common::Exceptions` when a
      service call fails — upstream timeouts should raise, not
      return nil or false.
    </rule>
    <rule enforcement="must">
      Emit a metric on each retry attempt, log once when retries
      exhaust, then raise — silent exhaustion causes data loss.
    </rule>
    <rule enforcement="should">
      Let exceptions propagate unless you can handle them
      meaningfully — catching without adding value just hides
      failures from APM.
    </rule>
  </rules>

  <investigate_before_answering>
    <step>Read the full method containing the rescue block to understand what the method is supposed to return on success vs failure.</step>
    <step>Identify all callers of the method — do they check for nil/false returns, or do they expect exceptions? Changing from nil-return to raise-on-failure will break callers that check `if result.nil?`.</step>
    <step>Determine whether the rescue block is the only place the error is observed. If no metric or log captures the failure, APM is completely blind.</step>
    <step>Check if the method is inside a retry loop. If so, determine whether retries emit metrics and whether exhaustion raises or returns nil.</step>
    <step>Determine the correct typed exception from `Common::Exceptions` based on the failure mode (timeout vs connection failure vs malformed response). Do not suggest fixes based on the rescue block alone. The correct remediation depends on what callers expect and how the failure should propagate.</step>
    <step>**Sidekiq non-retryable error check (MANDATORY).** If the code is in a Sidekiq job and the rescue block intentionally does NOT re-raise to PREVENT Sidekiq retries for non-retryable errors (e.g., upstream 400, permanent validation failure), this is NOT a violation — it is correct behavior. Re-raising in a Sidekiq job triggers retries, so swallowing after logging/notification for permanently-failing work is the right pattern. Check: (1) Is this a Sidekiq job? (2) Does the rescue distinguish retryable from non-retryable errors? (3) Does it log, notify, or emit metrics before swallowing? If all three are true, this is a FALSE POSITIVE — do not flag it. NEVER recommend re-raising non-retryable errors in Sidekiq jobs — this causes repeated retries of permanently failing work.</step>
  </investigate_before_answering>

  <severity_assessment>
    <critical>silent nil/false return in code handling PII, PHI, or benefits
claims data</critical>
    <critical>silent retry exhaustion in a submission pipeline where data
loss is possible</critical>
    <high>rescue block returning nil in service layer calling external
APIs (BGS, MPI, Lighthouse)</high>
    <high>rescue block returning false in code where false is a valid
business outcome (access checks)</high>
    <medium>rescue block returning empty collection in internal utility
with no external dependencies</medium>
    <false_positive>Sidekiq job that intentionally swallows non-retryable
errors after logging/notification/metrics — re-raising would cause
unwanted retries of permanently failing work. This is correct
Sidekiq error handling, not error swallowing.</false_positive>
  </severity_assessment>

  <pr_comment_template>
    **Don't Swallow Errors** | `HIGH`

    `{{file_path}}:{{line_number}}` -- rescue block returns `{{return_value}}`
    instead of raising, making this failure invisible to APM and indistinguishable
    from a valid "no data" response.

    **Why this matters:** Callers interpret `{{return_value}}` as a normal business
    outcome (no results, not eligible, etc.) when the actual cause is an upstream
    failure. On-call engineers cannot distinguish outages from missing data. APM
    sees nothing.

    **Suggested fix:**
    ```ruby
    {{suggested_code}}
    ```

    **Verify:**
    - [ ] Rescue raises typed exception (not nil/false)
    - [ ] Cause chain preserved (Ruby sets `$!.cause` automatically when raising from within rescue)
    - [ ] Callers updated to handle exception (not checking for nil)
    - [ ] APM would see this error
    - [ ] If Sidekiq job: non-retryable errors are correctly NOT re-raised (swallowing is OK after logging/notification)

    [Play: Don't Swallow Errors](16-dont-swallow-errors.md)
  </pr_comment_template>

</agent_play>
-->

### Do

- Raise a typed exception when a service call fails:
  ```ruby
  rescue Faraday::TimeoutError
    raise Common::Exceptions::ServiceUnavailable.new(detail: 'Upstream service timed out')
    # Ruby automatically sets $!.cause to the caught Faraday::TimeoutError
  ```
- Specify exception classes in rescue blocks:
  ```ruby
  rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
    # handle specific failures
  ```
- Emit metrics on each retry attempt, log once when exhausted, then raise:
  ```ruby
  rescue Faraday::TimeoutError
    retries += 1
    StatsD.increment('api.claims.submit.retry', tags: ["attempt:#{retries}"])
    retry if retries < 3
    Rails.logger.error('Retries exhausted', { attempts: retries })
    raise Common::Exceptions::GatewayTimeout.new(detail: 'Upstream timed out after retries')
  ```

### Don't

- Return `nil` or `false` from a rescue block to hide a failure:
  ```ruby
  rescue Faraday::TimeoutError => e
    Rails.logger.warn("Service call failed: #{e.message}")
    nil  # caller thinks "no data" instead of "service down"
  ```
- Let retry loops exhaust silently:
  ```ruby
  rescue Faraday::TimeoutError => e
    retries += 1
    retry if retries < 3
    nil  # caller assumes success, data never submitted
  ```
- Catch exceptions unless you can handle them meaningfully — if you cannot add value, let the exception propagate

## Anti-Patterns

### Silent Nil Return on Service Error

#### Anti-Pattern

```ruby
# Anti-pattern: service timeout returns nil, caller thinks "no data"
def fetch_veteran_status(user)
  response = ExternalService::Client.new.get_status(user:)
  response.status
rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
  Rails.logger.warn("Service call failed: #{e.message}")
  nil  # caller sees nil, thinks "veteran has no status"
end
```

#### Golden Pattern

```ruby
def fetch_veteran_status(user)
  response = ExternalService::Client.new.get_status(user:)
  response.status
rescue Faraday::TimeoutError, Faraday::ConnectionFailed
  # Raise typed exception — caller and APM both see the failure
  # Ruby automatically preserves the cause chain
  raise Common::Exceptions::ServiceUnavailable.new(detail: 'Upstream service unavailable')
end
```

### Sidekiq Non-Retryable Errors (NOT a Violation)

In Sidekiq jobs, intentionally swallowing non-retryable errors after logging/notification is **correct behavior**. Re-raising would cause Sidekiq to retry permanently-failing work.

```ruby
# CORRECT — this is NOT error swallowing, it's intentional retry control
def handle_upload_error(appeal, e)
  log_upload_error(appeal, e)
  appeal.update_status(status: 'error', code: e.code, detail: e.detail)

  # Re-raise retryable errors so Sidekiq will retry
  raise if RETRYABLE_STATUS_CODES.include?(e.upstream_http_resp_status)

  # Non-retryable: log/notify but do NOT re-raise — Sidekiq would retry uselessly
  notify(error_payload)
end
```

**Key criteria for this to be acceptable:**
1. The code is in a Sidekiq job (not a controller or service)
2. It distinguishes retryable from non-retryable errors
3. It logs, notifies, or emits metrics before swallowing
4. Re-raising retryable errors IS done (only non-retryable are swallowed)

**NEVER recommend re-raising non-retryable errors in Sidekiq jobs.** This causes repeated retries of permanently failing work, potentially hammering upstream services that already rejected the request.

### Silent Retry Exhaustion

#### Anti-Pattern

```ruby
# Anti-pattern: retries exhaust silently, returns nil as if successful
def submit_claim(claim_data)
  retries = 0
  begin
    ExternalService::Client.new.submit(claim_data)
  rescue Faraday::TimeoutError => e
    retries += 1
    retry if retries < 3
    Rails.logger.warn("Retries exhausted for claim submission")
    nil  # caller assumes success, claim never submitted
  end
end
```

#### Golden Pattern

```ruby
def submit_claim(claim_data)
  retries = 0
  begin
    ExternalService::Client.new.submit(claim_data)
  rescue Faraday::TimeoutError
    retries += 1
    StatsD.increment('api.claims.submit.retry', tags: ["attempt:#{retries}"])
    retry if retries < 3
    Rails.logger.error('Claim submission retries exhausted',
      { claim_id: claim_data[:id], attempts: retries })
    raise Common::Exceptions::GatewayTimeout.new(detail: 'Upstream timed out after retries')
  end
end
```
