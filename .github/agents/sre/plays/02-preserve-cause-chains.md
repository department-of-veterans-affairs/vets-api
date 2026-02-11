---
id: preserve-cause-chains
title: Always Preserve the Cause Chain When Wrapping Exceptions
version: 2
severity: CRITICAL
category: exception-handling
tags:
- cause-chain
- exception-wrapping
- stack-trace
- apm-traceability
- sidekiq-retry
language: ruby
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

  <retrieval_triggers>
    <trigger>exception wrapped without preserving cause chain</trigger>
    <trigger>APM shows wrapper exception but not original error</trigger>
    <trigger>raise new exception loses original stack trace</trigger>
    <trigger>Sidekiq wrong retry strategy due to exception type change</trigger>
    <trigger>raise string interpolation destroys exception class</trigger>
    <trigger>cause chain lost when re-raising exception</trigger>
  </retrieval_triggers>

  <detection>
    <pattern name="raise_new_exception_without_cause" confidence="medium">
      <signature>raise\s+\w+Exception\.new\([^)]*\)\s*$</signature>
      <description>
        Raises a new exception class without passing `cause:` as a
        keyword argument. The original exception's stack trace, class,
        and HTTP status are lost. Medium confidence because some
        exception constructors accept cause implicitly or the raise
        may occur outside a rescue block.
      </description>
      <example>raise BenefitsClaims::ServiceException.new(e.response)</example>
      <example>raise Common::Exceptions::BackendServiceException.new(nil, detail: e.message)</example>
    </pattern>
    <pattern name="stringified_reraise" confidence="high">
      <signature>raise\s+".*#\{.*\}"</signature>
      <description>
        Creates a new RuntimeError using string interpolation of the
        caught exception. This completely destroys the original
        exception class, backtrace, and cause chain. The result is
        always a generic RuntimeError with only a message string. High
        confidence because this is never the correct pattern.
      </description>
      <example>raise "error: #{e}"</example>
      <example>raise "Failed: #{e.message}"</example>
    </pattern>
    <pattern name="wrap_with_message_only" confidence="high">
      <signature>raise\s+\w+\.new\(.*\.message\)</signature>
      <description>
        Wraps an exception by extracting only the `.message` string
        into a new exception. Loses the original exception class, full
        backtrace, HTTP status code, and any nested cause chain. High
        confidence because `.message` alone is never sufficient
        context for debugging.
      </description>
      <example>raise ServiceException.new(e.message)</example>
      <example>raise Common::Exceptions::BackendServiceException.new(nil, detail: e.message)</example>
    </pattern>
    <heuristic>
      A rescue block that raises a new exception class without
      `cause: e` in the constructor arguments is a strong signal of
      a broken cause chain. Check whether the exception class
      constructor accepts a `cause:` keyword argument.
    </heuristic>
    <heuristic>
      A rescue block that uses string interpolation to build a new
      error message (`raise "error: #{e}"`) always destroys the
      cause chain. This pattern is commonly found in Sidekiq jobs
      where it was copy-pasted across multiple files.
    </heuristic>
    <heuristic>
      A rescue block in a service wrapper that catches Faraday
      errors and raises a module-specific exception without `cause:`
      breaks APM traceability for all upstream HTTP errors (status
      codes, timeouts, connection failures).
    </heuristic>
    <false_positive>
      `raise` (bare re-raise) without arguments inside a rescue
      block is correct. Ruby automatically preserves the original
      exception when using bare `raise`. This is the preferred
      pattern when no additional context needs to be added.
    </false_positive>
    <false_positive>
      Exception constructors that accept the original exception as a
      positional argument (not `cause:`) and internally set the
      cause chain. Verify by reading the exception class definition
      before flagging.
    </false_positive>
    <false_positive>
      Raising a new exception in code that is NOT inside a rescue
      block. The detection patterns may match raise statements
      outside of rescue contexts where there is no caught exception
      to preserve.
    </false_positive>
  </detection>

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

  <default_to_action>
    When you detect a broken cause chain with high confidence,
    provide a fix adding `cause: e` or replacing stringified
    re-raise with bare `raise`. Read the exception class
    definition to verify it accepts `cause:` before suggesting.
  </default_to_action>

  <verify>
    <command description="No stringified re-raise remains in changed file">
      grep -On 'raise\s+".*#\{' {{file_path}} &amp;&amp; exit 1 || exit 0
    </command>
    <command description="No message-only wrap remains">
      grep -On 'raise\s+\w+\.new\(.*\.message\)' {{file_path}} &amp;&amp; exit 1 || exit 0
    </command>
    <command description="Run specs for changed file">
      bundle exec rspec {{spec_path}}
    </command>
    <command description="RuboCop passes for changed file">
      bundle exec rubocop {{file_path}}
    </command>
  </verify>

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

# Always Preserve the Cause Chain When Wrapping Exceptions

When you catch an exception and raise a new one, pass the caught exception as `cause:` so APM, logs, and Sidekiq can trace back to the original failure. In `rescue SomeError => e`, the variable `e` holds the caught exception — pass it as `cause: e`. If you named the variable differently (e.g., `rescue SomeError => error`), pass `cause: error`.

> [!CAUTION]
> Losing the cause chain destroys forensic traceability — you'll know something failed, but not *why*.

## Why It Matters

When you wrap an exception without `cause: e`, APM shows "ServiceException at line 46" but the original `Faraday::ServerError` is gone — the HTTP 503 status becomes invisible. Your stack trace points to the re-raise line, not where the connection actually failed. Sidekiq sees a `RuntimeError` instead of a `TimeoutError`, picks the wrong retry strategy, and the job fails permanently. When 500 errors spike, you can't tell a timeout from a 404 from a bug, so you're stuck grepping logs for hours.

## Guidance

Always pass the caught exception as `cause:` when raising a new exception inside a `rescue` block. If you don't need to add context, use `raise` without arguments instead — Ruby automatically preserves the original exception.

### Do

- `raise ServiceException.new("BGS failed", cause: e)` — wraps with context, preserves the chain
- `raise` (no arguments) — re-raises the original exception unchanged when no context needed

### Don't

- `raise "error: #{e}"` — creates a RuntimeError (loses class, backtrace, cause chain)
- `raise ServiceException.new(e.message)` — extracts only the string (loses everything else)
- `raise ServiceException.new(e.response)` without `cause: e` — HTTP status lost from APM

## Anti-Patterns

### Lighthouse Benefits Claims Service

**Source:** [lib/lighthouse/benefits_claims/service.rb:45-46](https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/lib/lighthouse/benefits_claims/service.rb#L45-L46)

```ruby
rescue Faraday::ClientError, Faraday::ServerError => e
  raise BenefitsClaims::ServiceException.new(e.response), 'Lighthouse Error'
  # Missing cause: parameter — original Faraday exception lost
end
```

**Problem:** Missing `cause: e` — APM sees only `ServiceException: Lighthouse Error` at line 46. The original `Faraday::ServerError` with its 503 status, timeout location, and connection details is destroyed. You can't distinguish a 404 from a 503 from a network timeout.

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

**Source:** [modules/mobile/app/controllers/mobile/v0/dependents_controller.rb:11-12](https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/modules/mobile/app/controllers/mobile/v0/dependents_controller.rb#L11-L12)

```ruby
rescue => e  # Catches ALL exceptions (typos, timeouts, DB errors)
  raise Common::Exceptions::BackendServiceException.new(
    nil,
    detail: e.message  # Only string — loses stack trace, exception type, cause chain
  )
end
```

**Problem:** `e.message` extracts only the string — original exception class, backtrace, and cause chain are gone. APM sees `BackendServiceException` at controller.rb:12 for every error. A BGS timeout looks identical to a `NoMethodError` from a typo.

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

**Source:** [app/sidekiq/income_limits/std_state_import.rb:52](https://github.com/department-of-veterans-affairs/vets-api/blob/master/app/sidekiq/income_limits/std_state_import.rb#L52)

> Found in **5 income limit Sidekiq jobs** — systemic copy-paste pattern.

```ruby
def perform
  # ... CSV import logic ...
rescue => e
  raise "error: #{e}"
  # Creates NEW RuntimeError — original class, backtrace, and cause chain destroyed
end
```

**Problem:** `raise "error: #{e}"` creates a new `RuntimeError` with a flat string. The original exception class is gone, the backtrace points to this line only, and Sidekiq picks the wrong retry strategy because it sees `RuntimeError` instead of `Faraday::ConnectionFailed`.

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

## References

- [Ruby Exception#cause](https://ruby-doc.org/core/Exception.html#method-i-cause)
