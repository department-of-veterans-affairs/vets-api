---
id: preserve-cause-chains
title: Always Preserve the Cause Chain When Wrapping Exceptions
severity: CRITICAL
---

<!--
<agent_play>

  <context>
    APM shows "ServiceException at line 46" but the original
    Faraday::ServerError is lost and the HTTP 503 status becomes
    invisible. The stack trace shows only the re-raise line, destroying
    the root cause location so you cannot find where the connection
    failed. Sidekiq sees a RuntimeError instead of a TimeoutError,
    applies the wrong retry strategy, and the job fails permanently.
    When 500 errors spike, you cannot tell a timeout from a 404 from a
    bug, requiring manual log grep that wastes hours.
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
    <play id="bare-rescue" relationship="complementary" />
    <play id="prefer-typed-exceptions" relationship="complementary" />
  </related_plays>

  <rules>
    <rule enforcement="must">
      When catching an exception to add context, always wrap it in a
      new typed exception with `cause: e`.
    </rule>
    <rule enforcement="must_not">
      Never catch and re-raise without setting `cause:` — the
      original stack trace will be lost.
    </rule>
    <rule enforcement="must_not">
      Never use `raise "error: #{e}"` — this creates a RuntimeError
      and destroys the original exception class, backtrace, and
      cause chain.
    </rule>
    <rule enforcement="must">
      APM tools and logs need the full cause chain to trace root
      causes — always preserve it.
    </rule>
    <rule enforcement="should">
      If not adding context when re-raising, use bare `raise` to
      preserve the original exception automatically.
    </rule>
    <rule enforcement="verify">
      APM traces show full chain: RuntimeError -> ServiceException
      -> Faraday::ServerError
    </rule>
    <rule enforcement="verify">
      Stack trace shows original failure location (not just wrapper
      line)
    </rule>
    <rule enforcement="verify">
      Sidekiq can inspect exception type for retry strategy
    </rule>
    <rule enforcement="verify">
      HTTP status codes visible in APM (from original Faraday
      exception)
    </rule>
  </rules>

  <investigate_before_answering>
    <step>Read the full method containing the rescue block to understand what exception is being caught and what new exception is being raised.</step>
    <step>Identify the exception class being raised — does its constructor accept a `cause:` keyword argument? If not, the class itself may need to be updated before the fix can be applied.</step>
    <step>Check if the code uses `raise "string"` pattern — this always creates a new RuntimeError and is never correct. The fix is `raise` without arguments or a typed exception with `cause:` passing the caught exception.</step>
    <step>Determine whether the rescue block catches specific exceptions or uses bare rescue. If bare rescue, the cause chain fix should be combined with narrowing the rescue clause (see Play: Never Use Broad Rescues).</step>
    <step>Check if Sidekiq retry behavior depends on the exception type. If so, preserving the original class is critical for correct retry strategy. Do not suggest adding `cause: e` without first verifying that the exception constructor accepts it. Read the exception class definition if needed.</step>
  </investigate_before_answering>

  <severity_assessment>
    <critical>cause chain lost in code handling PII, PHI, or benefits claims
data</critical>
    <critical>stringified re-raise in Sidekiq job where retry strategy
depends on exception type</critical>
    <critical>cause chain lost in service layer calling external APIs (BGS,
MPI, Lighthouse) — APM blackout for upstream errors</critical>
    <high>exception wrapped without cause: in controller handling user-
facing requests</high>
    <high>cause chain lost in code where HTTP status codes must
propagate for correct error responses</high>
    <medium>cause chain lost in internal utility with no external
dependencies or retry behavior</medium>
  </severity_assessment>

  <pr_comment_template>
    **Always Preserve the Cause Chain When Wrapping Exceptions** | `CRITICAL`

    `{{file_path}}:{{line_number}}` — {{one_line_violation_description}}

    **Why this matters:** Without the cause chain, APM shows only the wrapper
    exception at the re-raise line. The original error's stack trace, HTTP status
    code, and exception class are lost. Engineers cannot determine root cause
    without manual log analysis. Sidekiq retry strategies may apply the wrong
    policy when the original exception type is destroyed.

    **Suggested fix:**
    ```ruby
    {{suggested_code}}
    ```

    **Verify:**
    - [ ] `cause:` passed to exception constructor with the caught exception (or `raise` without arguments used)
    - [ ] No `raise "error: #{e}"` patterns remain
    - [ ] APM traces show full chain: wrapper -> original exception
    - [ ] Stack trace shows original failure location

    [Play: Always Preserve the Cause Chain](plays/preserve-cause-chains.md)
  </pr_comment_template>

</agent_play>
-->

### Do

- `raise ServiceException.new("BGS failed", cause: e)` — wraps with context, preserves the chain
- `raise` (no arguments) — re-raises the original exception unchanged when no context needed

### Don't

- `raise "error: #{e}"` — creates a RuntimeError (loses class, backtrace, cause chain)
- `raise ServiceException.new(e.message)` — extracts only the string (loses everything else)
- `raise ServiceException.new(e.response)` without `cause: e` — HTTP status lost from APM

## Anti-Patterns

### Lighthouse Benefits Claims Service

```ruby
rescue Faraday::ClientError, Faraday::ServerError => e
  raise BenefitsClaims::ServiceException.new(e.response), 'Lighthouse Error'
  # Missing cause: parameter — original Faraday exception lost
end
```

**Corrected:**

```ruby
rescue Faraday::ClientError, Faraday::ServerError => e
  raise BenefitsClaims::ServiceException.new(
    e.response,
    'Lighthouse Error',
    cause: e  # Preserves original exception with full stack trace
  )
end
```

### Mobile Dependents Controller

```ruby
rescue => e  # Catches ALL exceptions (typos, timeouts, DB errors)
  raise Common::Exceptions::BackendServiceException.new(
    nil,
    detail: e.message  # Only string — loses stack trace, exception type, cause chain
  )
end
```

**Corrected:**

```ruby
rescue BGS::ServiceError => e
  raise Common::Exceptions::BackendServiceException.new(
    'BGS',
    detail: 'BGS service unavailable',
    cause: e  # Preserves original exception object with stack trace
  )
rescue ActiveRecord::RecordNotFound => e
  raise Common::Exceptions::RecordNotFound.new(
    detail: "Dependent not found",
    cause: e  # Preserves ActiveRecord exception with query details
  )
end
```

### Income Limit Import Jobs — Stringified Re-raise

```ruby
def perform
  # ... CSV import logic ...
rescue => e
  raise "error: #{e}"
  # Creates NEW RuntimeError — original class, backtrace, and cause chain destroyed
end
```

**Corrected:**

```ruby
def perform
  # ... CSV import logic ...
rescue => e
  raise  # Re-raises original exception with full context
  # Or if adding context:
  raise ImportError.new("CSV import failed", cause: e)
end
```
