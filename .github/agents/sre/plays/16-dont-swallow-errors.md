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
    - [ ] Cause chain preserved with `cause: e`
    - [ ] Callers updated to handle exception (not checking for nil)
    - [ ] APM would see this error

    [Play: Don't Swallow Errors](16-dont-swallow-errors.md)
  </pr_comment_template>

</agent_play>
-->

### Do

- Raise a typed exception when a service call fails:
  ```ruby
  rescue Faraday::TimeoutError => e
    raise Common::Exceptions::ServiceUnavailable.new(cause: e)
  ```
- Specify exception classes in rescue blocks:
  ```ruby
  rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
    # handle specific failures
  ```
- Emit metrics on each retry attempt, log once when exhausted, then raise:
  ```ruby
  rescue Faraday::TimeoutError => e
    retries += 1
    StatsD.increment('api.claims.submit.retry', tags: ["attempt:#{retries}"])
    retry if retries < 3
    Rails.logger.error('Retries exhausted', { attempts: retries })
    raise Common::Exceptions::GatewayTimeout.new(cause: e)
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
rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
  # Raise typed exception — caller and APM both see the failure
  raise Common::Exceptions::ServiceUnavailable.new(cause: e)
end
```

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
  rescue Faraday::TimeoutError => e
    retries += 1
    StatsD.increment('api.claims.submit.retry', tags: ["attempt:#{retries}"])
    retry if retries < 3
    Rails.logger.error('Claim submission retries exhausted',
      { claim_id: claim_data[:id], attempts: retries })
    raise Common::Exceptions::GatewayTimeout.new(cause: e)
  end
end
```
