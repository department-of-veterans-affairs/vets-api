---
id: dont-swallow-errors
title: Don't swallow errors (retries, fallbacks, silent returns)
version: 2
severity: HIGH
category: exception-handling
tags:
- error-swallowing
- silent-failure
- nil-return
- rescue
- apm-blackout
language: ruby
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

  <retrieval_triggers>
    <trigger>method returns nil instead of raising exception</trigger>
    <trigger>rescue block swallows error silently</trigger>
    <trigger>APM not seeing errors after rescue</trigger>
    <trigger>silent failure returns false on error</trigger>
    <trigger>retry exhausts without raising</trigger>
  </retrieval_triggers>

  <detection>
    <pattern name="rescue_returning_nil" confidence="high">
      <signature>rescue.*\n\s*nil\s*$</signature>
      <description>
        A rescue block whose body returns nil. This silently swallows
        all caught exceptions and returns a value callers interpret as
        "no data" rather than "something failed." Upstream timeouts
        become indistinguishable from missing records.
      </description>
      <example>rescue =&gt; e\n  nil</example>
      <example>rescue Faraday::Error\n  nil</example>
      <example>rescue\n  nil</example>
    </pattern>
    <pattern name="rescue_returning_false" confidence="high">
      <signature>rescue.*\n\s*false\s*$</signature>
      <description>
        A rescue block whose body returns false. Callers interpret
        false as a negative business result (e.g., "access denied,"
        "not eligible") rather than a system failure. Masks
        infrastructure errors as business logic outcomes.
      </description>
      <example>rescue =&gt; e\n  false</example>
      <example>rescue Faraday::TimeoutError\n  false</example>
    </pattern>
    <pattern name="rescue_returning_empty_array" confidence="medium">
      <signature>rescue.*\n\s*\[\]\s*$</signature>
      <description>
        A rescue block returning an empty array. Callers iterate over
        it without error, producing empty pages or missing results.
        Medium confidence because some methods legitimately return
        empty arrays as a default, but when combined with external
        service calls this is a strong signal of error swallowing.
      </description>
      <example>rescue =&gt; e\n  []</example>
      <example>rescue Faraday::Error\n  []</example>
    </pattern>
    <pattern name="rescue_returning_empty_hash" confidence="medium">
      <signature>rescue.*\n\s*\{\}\s*$</signature>
      <description>
        A rescue block returning an empty hash. Callers access keys
        and get nil values without knowing the upstream call failed.
        Medium confidence because some methods use empty hashes as
        defaults, but combined with service calls this masks failures.
      </description>
      <example>rescue =&gt; e\n  {}</example>
      <example>rescue Faraday::Error\n  {}</example>
    </pattern>
    <heuristic>
      A method that calls an external service (BGS, MPI, Lighthouse,
      Faraday-based clients) and has a rescue block returning nil,
      false, or an empty collection is a high-priority violation.
      Upstream failures must not look like "no results."
    </heuristic>
    <heuristic>
      A retry loop that catches exceptions and returns nil or a
      default value when retries are exhausted indicates silent
      retry exhaustion. The caller cannot distinguish "success with
      no data" from "all retries failed."
    </heuristic>
    <heuristic>
      A method where the rescue block does not call `raise`,
      `Rails.logger.error`, or emit a StatsD metric is likely
      swallowing errors completely. Check whether any observability
      signal escapes the rescue.
    </heuristic>
    <false_positive>
      `rescue ActiveRecord::RecordNotFound => e; nil` in a
      `find_by`-style method where the caller expects nil for "not
      found" and nil genuinely means "no record exists." This is
      acceptable only when the rescue targets a specific exception
      and the nil represents a valid business outcome, not a masked
      infrastructure failure.
    </false_positive>
    <false_positive>
      `rescue Redis::BaseConnectionError => e; default_value` in a
      cache-read helper where the system is designed to degrade
      gracefully when the cache is unavailable. Acceptable only
      when: (1) a metric is emitted, (2) the fallback is documented,
      and (3) the exception class is specific.
    </false_positive>
  </detection>

  <rules>
    <rule enforcement="must_not">
      Never return nil or false from a rescue block to hide a
      failure — upstream timeouts should raise, not look like "no
      results."
    </rule>
    <rule enforcement="must_not">
      Never let retry loops exhaust silently — emit a metric on each
      attempt, log once when exhausted, then raise.
    </rule>
    <rule enforcement="must">
      Always specify exception classes in rescue blocks (see Play:
      Never Use Broad Rescues).
    </rule>
    <rule enforcement="must">
      Always raise a typed exception when a service call fails — use
      Common::Exceptions classes that map to HTTP status codes.
    </rule>
    <rule enforcement="should_not">
      Don't catch an exception unless you can handle it meaningfully
      — if you can't, let it propagate.
    </rule>
    <rule enforcement="verify">
      APM sees exceptions (not swallowed by rescue -> nil)
    </rule>
    <rule enforcement="verify">
      Timeouts raise ServiceUnavailable (don't return nil)
    </rule>
    <rule enforcement="verify">
      Failed operations never return nil/false (they raise)
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

  <default_to_action>
    When you detect error swallowing with high confidence, compose
    a PR comment that includes: 1. The specific violation (which
    rescue block returns nil/false and where) 2. Why it matters
    (callers cannot distinguish failure from "no data," APM is
    blind to the error) 3. A concrete code suggestion replacing
    the silent return with a typed exception raise, including
    `cause: e` 4. The verification checklist items relevant to
    this specific case 5. A link to this play for full context Do
    not simply flag the violation — provide the fix. Read the
    protected code and callers to determine the correct exception
    class before suggesting a replacement.
  </default_to_action>

  <verify>
    <command description="No rescue block returning nil remains in changed file">
      grep -On 'rescue.*\n\s*nil\s*$' {{file_path}} &amp;&amp; exit 1 || exit 0
    </command>
    <command description="No rescue block returning false remains">
      grep -On 'rescue.*\n\s*false\s*$' {{file_path}} &amp;&amp; exit 1 || exit 0
    </command>
    <command description="Run specs for changed file">
      bundle exec rspec {{spec_path}}
    </command>
    <command description="RuboCop passes for changed file">
      bundle exec rubocop {{file_path}}
    </command>
  </verify>

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

    [Play: Don't Swallow Errors](plays/dont-swallow-errors.md)
  </pr_comment_template>

</agent_play>
-->

# Don't swallow errors (retries, fallbacks, silent returns)

When a rescue block returns `nil`, `false`, or an empty collection instead of raising, the failure becomes invisible. Callers interpret the return value as a normal business outcome, and APM never sees the error.

> [!CAUTION]
> Silent failures hide root causes and make debugging impossible. Upstream timeout != "user denied access."
>
> **Note:** This play's anti-pattern (VRE Veteran Claim bare rescue) is covered in [Play: Never Use Broad Rescues](03-never-use-bare-rescues.md). See that play for full Anti-Pattern -> Golden Pattern -> Impact analysis.

## Why It Matters

When a BGS timeout returns `nil`, your caller thinks "no file number found" when in reality the upstream service timed out — and there is no way to distinguish the two. A bare rescue that swallows a `NoMethodError` and returns `false` makes the caller think "access denied" when it is actually a code bug. When retries exhaust silently and the method returns `nil`, the caller assumes success, data is never submitted, and there is zero visibility into the failure. APM sees nothing because errors are swallowed before telemetry fires, so debugging requires manual log analysis that wastes hours.

## Guidance

When a service call fails, raise a typed exception instead of returning a sentinel value. Specify exception classes in every rescue block so you only catch what you can handle meaningfully. For retry loops, emit a metric on each attempt, log once when retries are exhausted, then raise — never return `nil` silently.

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

## Reference

**Common error-swallowing patterns to avoid:**

- Returning `nil` or `false` to hide failures
- Using bare `rescue` without specific exception classes
- Catching exceptions without meaningful handling
- Retrying without bounds or logging exhaustion

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


**Violations:**
- Returns nil on service failure — caller cannot distinguish "no status exists" from "service timed out"
- APM does not record the error because it was caught and discarded
- Downstream code that checks `if status.nil?` takes the "no data" branch instead of the "service down" branch
- No metric emitted — monitoring dashboards show zero errors during an outage

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


**Improvements:**
- Raises typed exception instead of returning nil — failure is explicit
- APM captures the error with full cause chain
- Caller receives ServiceUnavailable and can decide how to handle (retry, degrade, report)
- Monitoring dashboards reflect the outage accurately

#### Impact

**Without raising (anti-pattern):**
- Caller interprets nil as "no status exists" instead of "service failed"
- APM sees nothing — error swallowed before telemetry
- Monitoring dashboards show zero errors during actual outage
- Engineers cannot distinguish "veteran has no status" from "upstream timeout"

**With raising (golden pattern):**
- Failure is explicit — caller receives ServiceUnavailable exception
- APM captures error with full cause chain for tracing
- Monitoring dashboards reflect the outage accurately
- Engineers immediately know the difference between missing data and service failure

---

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


**Violations:**
- Returns nil after retry exhaustion — caller cannot tell success from failure
- No metric emitted on retry attempts — no visibility into service degradation
- Claim data may be permanently lost if caller does not re-enqueue
- APM sees no error — three timeouts invisible to monitoring

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


**Improvements:**
- Emits StatsD metric on each retry attempt for dashboards and alerting
- Logs once when retries are exhausted (not on each attempt)
- Raises GatewayTimeout instead of returning nil — caller knows submission failed
- Preserves cause chain with `cause: e` for APM tracing

#### Impact

**Without raising (anti-pattern):**
- Caller assumes success when claim was never submitted
- No metric on retry attempts — invisible service degradation
- Claim data may be permanently lost
- APM sees nothing — three timeouts invisible

**With raising (golden pattern):**
- Caller receives GatewayTimeout and can handle appropriately (re-enqueue, alert)
- Metrics show retry attempts for dashboards and alerting
- No silent data loss — failure is explicit
- APM traces show full context with cause chain

> [!NOTE]
> For comprehensive retry behavior guidance (log spam, bare rescue in retry loops, Retry-After headers, inflated metrics), see [Play 21: Retry Smart](21-respect-retry-headers-when-calling-upstream.md).

---

## References

- [Ruby Exception Hierarchy](https://ruby-doc.org/core/Exception.html)
