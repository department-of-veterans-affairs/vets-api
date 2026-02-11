---
id: dont-catch-log-reraise
title: Don't catch, log, and re-raise (no double handling)
version: 2
severity: HIGH
category: exception-handling
tags:
- double-handling
- log-spam
- telemetry-duplication
- rescue
- apm
language: ruby
---

<!--
<agent_play>

  <context>
    A single exception generates two telemetry entries—one from the
    manual log and one from APM—creating duplicate backtraces with zero
    additional value. During an incident, an engineer sees two error
    signals and thinks two separate failures occurred, wasting time
    correlating what is actually a single exception. Every exception
    creates two to three redundant log lines even though APM already
    captures the backtrace, params, user, and timing automatically. The
    manual log adds no context that APM does not already have, so the
    duplication is pure noise that drowns real issues.
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
    <play id="prefer-structured-logs" relationship="complementary" />
  </related_plays>

  <retrieval_triggers>
    <trigger>catch log and re-raise same exception</trigger>
    <trigger>manual backtrace logging duplicates APM</trigger>
    <trigger>rescue block logs error then raises again</trigger>
    <trigger>duplicate telemetry entries for single error</trigger>
    <trigger>exception logged twice in APM and logs</trigger>
  </retrieval_triggers>

  <detection>
    <pattern name="catch_log_reraise" confidence="high">
      <signature>rescue.*\n.*logger\.(error|warn).*\n.*raise\b</signature>
      <description>
        A rescue block that logs the exception and then re-raises it.
        This produces two telemetry entries for a single failure: one
        from the manual log call and one from APM capturing the re-
        raised exception. The manual log adds zero value because APM
        already captures the exception class, message, full backtrace,
        and request context.
      </description>
      <example>rescue =&gt; e; Rails.logger.error(e.message); raise</example>
      <example>rescue StandardError =&gt; e; logger.warn("failed: #{e}"); raise e</example>
    </pattern>
    <pattern name="manual_backtrace_logging" confidence="high">
      <signature>\.backtrace\.join</signature>
      <description>
        Manual backtrace logging via `e.backtrace.join("\n")` or
        similar. APM captures the full backtrace automatically when an
        exception propagates. Logging it manually duplicates the
        backtrace in logs while APM records the same information with
        richer context (request URL, params, user, timing).
      </description>
      <example>Rails.logger.error e.backtrace.join("\n")</example>
      <example>logger.error(e.backtrace.join('\n'))</example>
    </pattern>
    <pattern name="log_message_then_raise" confidence="high">
      <signature>logger\.(error|warn).*\.message.*\n.*raise\b</signature>
      <description>
        Logging the exception message immediately before re-raising.
        The re-raised exception will be captured by APM with the same
        message plus full context. The manual log line is redundant
        noise.
      </description>
      <example>Rails.logger.error "Error: #{e.message}"\nraise</example>
      <example>logger.warn("Failed: #{e.message}")\nraise e</example>
    </pattern>
    <heuristic>
      A rescue block that contains both a
      `logger.error`/`logger.warn` call AND a `raise` (or `raise e`)
      on the next line is the strongest signal of the catch-log-
      reraise anti-pattern. The rescue adds no context — it just
      duplicates what APM captures automatically.
    </heuristic>
    <heuristic>
      Any call to `.backtrace.join` in a rescue block signals manual
      backtrace logging. APM captures the full backtrace with richer
      context (request URL, params, user, timing). Manual backtrace
      logging is always redundant.
    </heuristic>
    <heuristic>
      A rescue block that logs the exception and then renders an
      error response (without re-raising) may also be duplicating
      APM if the controller's ExceptionHandling concern would have
      caught and rendered the same error. Check whether removing the
      rescue entirely would produce the same behavior.
    </heuristic>
    <false_positive>
      Logging BEFORE wrapping with a new typed exception is
      acceptable if the log adds meaningful context not present in
      the new exception. Example: logging request/response payloads
      from an upstream service before raising `ServiceUnavailable`.
      The key test: does the log contain information that APM would
      NOT capture from the re-raised exception alone?
    </false_positive>
    <false_positive>
      Emitting StatsD metrics (counters, gauges) inside a rescue
      block before re-raising is acceptable. Metrics are not logs —
      they feed dashboards and alerts with pre-aggregated data that
      APM exception tracking does not replace.
    </false_positive>
    <false_positive>
      Logging at a different severity level to trigger specific
      alerting rules is acceptable if the team has alerting tied to
      log severity rather than APM exception counts. This should be
      migrated to APM-based alerting, but is not a violation of this
      play.
    </false_positive>
  </detection>

  <rules>
    <rule enforcement="must">
      Catch only when adding meaningful context or converting to a
      typed exception.
    </rule>
    <rule enforcement="must_not">
      Never log and re-raise the same exception — let APM record it
      once.
    </rule>
    <rule enforcement="must_not">
      Never manually log backtraces — APM captures the full
      backtrace automatically.
    </rule>
    <rule enforcement="should">
      Emit metrics (StatsD counters) for retry attempts, not logs.
    </rule>
    <rule enforcement="should">
      When adding context, wrap with `cause:` and re-raise a new
      typed exception.
    </rule>
    <rule enforcement="verify">
      One exception → One signal in APM (not two)
    </rule>
    <rule enforcement="verify">
      If catching, you're adding meaningful context (not just
      logging)
    </rule>
    <rule enforcement="verify">
      No manual backtrace logging (APM captures automatically)
    </rule>
  </rules>

  <investigate_before_answering>
    <step>Read the full rescue block to determine whether the log adds ANY context not already captured by APM (request/response payloads, business context, correlation IDs). If it does, this may not be a violation.</step>
    <step>Check whether the rescue block re-raises the same exception or wraps it in a new typed exception. Re-raising the same exception after logging is the violation. Wrapping with a new exception and cause chain is acceptable.</step>
    <step>Determine whether the code is at a controller boundary where the ExceptionHandling concern would catch the exception automatically. If so, the entire rescue block may be unnecessary.</step>
    <step>Check for StatsD metric calls in the rescue block — these are acceptable and should be preserved even if the logging is removed.</step>
    <step>Verify that removing the rescue block would not change the HTTP response behavior (e.g., if the rescue renders a custom error page).</step>
  </investigate_before_answering>

  <severity_assessment>
    <critical>catch-log-reraise in code handling PII, PHI, or financial data
where log duplication may expose sensitive fields</critical>
    <high>catch-log-reraise in controller actions or service layers
calling external APIs — duplicates telemetry during incidents</high>
    <high>manual backtrace logging in any rescue block — always
duplicates APM</high>
    <medium>catch-log-reraise in internal utility code where log volume
impact is lower</medium>
  </severity_assessment>

  <default_to_action>
    When you detect a catch-log-reraise violation with high
    confidence, compose a PR comment that includes: 1. The
    specific violation (which rescue block logs and re-raises) 2.
    Why it matters (duplicate telemetry, log spam, incident
    confusion) 3. A concrete code suggestion: either remove the
    rescue entirely or wrap with a typed exception using `cause:
    e` 4. A link to this play for full context Do not simply flag
    the violation — provide the fix. If the rescue block can be
    removed entirely, show the code without the rescue. If context
    wrapping is needed, show the typed exception pattern.
  </default_to_action>

  <verify>
    <command description="No manual backtrace logging remains in changed file">
      grep -On '\.backtrace\.join' {{file_path}} &amp;&amp; exit 1 || exit 0
    </command>
    <command description="No catch-log-reraise pattern remains">
      grep -Pzn 'rescue.*\n.*logger\.(error|warn).*\n.*raise\b' {{file_path}} &amp;&amp; exit 1 || exit 0
    </command>
    <command description="Run specs for changed file">
      bundle exec rspec {{spec_path}}
    </command>
    <command description="RuboCop passes for changed file">
      bundle exec rubocop {{file_path}}
    </command>
  </verify>

  <pr_comment_template>
    **Don't catch, log, and re-raise** | `HIGH`

    `{{file_path}}:{{line_number}}` — {{one_line_violation_description}}

    **Why this matters:** This rescue block logs the exception and then re-raises
    it, generating two telemetry entries for a single failure. APM automatically
    captures the exception class, message, full backtrace, and request context.
    The manual log adds zero information and creates noise during incidents.

    **Suggested fix:**
    ```ruby
    {{suggested_code}}
    ```

    - [ ] No manual backtrace logging (`e.backtrace.join` removed)
    - [ ] One exception generates one signal in APM (not two)
    - [ ] If wrapping, cause chain preserved with `cause: e`

    [Play: Don't catch, log, and re-raise](plays/dont-catch-log-reraise.md)
  </pr_comment_template>

</agent_play>
-->

# Don't Catch, Log, and Re-raise

Catching an exception just to log it and then re-raising the same exception creates duplicate telemetry with zero added value. This play explains when to catch and when to let APM do its job.

> [!CAUTION]
> Catching, logging, and then re-raising the **same** exception adds no value and **duplicates telemetry** (APM + logs).

## Why It Matters

When you catch an exception, log it, and re-raise, you generate two telemetry entries for a single failure: one from your manual log call and one from APM capturing the re-raised exception. During an incident, an engineer sees two error signals and wastes time figuring out whether two separate failures occurred or just one. Every exception creates two to three redundant log lines even though APM already captures the backtrace, params, user, and timing automatically. The manual log adds no context that APM does not already have, so the duplication is pure noise that drowns real issues and inflates error counts on dashboards.

## Guidance

The correct approach is to let exceptions propagate naturally so APM captures them once, with full context. Only catch an exception when you are adding meaningful information — such as wrapping it in a typed exception with a `cause:` chain — or when you need to emit a metric. If you are not adding context, remove the rescue block entirely.

### Do

- Catch only when adding meaningful context or converting to a typed exception:

  ```ruby
  rescue CemeteryService::UpstreamError => e
    raise Common::Exceptions::ServiceUnavailable.new(
      detail: "NCA cemetery database unavailable",
      cause: e  # Preserves original exception for APM
    )
  end
  ```

- Wrap with `cause: e` and re-raise a new typed exception when adding context:

  ```ruby
  raise AppSpecificError.new("meaningful context", cause: e)
  ```

- Emit metrics (StatsD counters) for retry attempts instead of logs:

  ```ruby
  rescue Faraday::TimeoutError => e
    StatsD.increment("service.retry_attempt")
    raise
  end
  ```

### Don't

- Log and re-raise the same exception — let APM record it once:

  ```ruby
  # BAD — duplicates telemetry
  rescue => e
    Rails.logger.error("Something failed: #{e.message}")
    raise
  end
  ```

- Manually log backtraces (`e.backtrace.join`) — APM captures them automatically:

  ```ruby
  # BAD — APM already has the full backtrace
  rescue => e
    Rails.logger.error e.backtrace.join("\n")
    raise
  end
  ```

- Log an exception then re-raise without adding any new context:

  ```ruby
  # BAD — zero information added beyond what APM captures
  rescue StandardError => e
    logger.warn("failed: #{e}")
    raise e
  end
  ```

## Anti-Patterns

### Cemeteries Controller

#### Anti-Pattern

[modules/simple_forms_api/.../cemeteries_controller.rb:14-17](https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/modules/simple_forms_api/app/controllers/simple_forms_api/v1/cemeteries_controller.rb#L14-L17)

```ruby
rescue => e
  Rails.logger.error "Cemetery controller error: #{e.message}"
  Rails.logger.error e.backtrace.join("\n")  # Manual backtrace logging
  render json: { error: 'Unable to load cemetery data' }, status: :internal_server_error
  # APM ALSO captures this exception with backtrace automatically
end
```

**Violations:**
- Catches the exception and manually logs backtrace via `e.backtrace.join("\n")`, duplicating what APM captures automatically
- `Rails.logger.error` with `e.message` duplicates the exception message APM already records
- Renders a generic error response instead of letting ExceptionHandling produce a standardized response (catch-log-render pattern)
- Zero value added — APM has backtrace, params, user, and timing automatically

#### Golden Pattern

```ruby
# Let APM capture it naturally - no rescue needed
def index
  @cemeteries = CemeteryService.all
  render json: @cemeteries
  # Exception propagates to Rails error handler → APM captures automatically
end

# OR if adding meaningful context:
rescue CemeteryService::UpstreamError => e
  raise Common::Exceptions::ServiceUnavailable.new(
    detail: "NCA cemetery database unavailable",
    cause: e  # Preserves original exception for APM
  )
end
```

**Improvements:**
- Removes manual backtrace logging entirely (APM captures automatically)
- Removes redundant `Rails.logger.error` calls (APM has the message)
- Exception propagates to ExceptionHandling concern for standardized response
- When wrapping, uses typed exception with `cause: e` to preserve chain
- One exception generates ONE signal in APM (not two)

#### Impact

**Without manual logging (let APM handle it):**
- One exception generates ONE signal in APM (exception class, message, full backtrace, request context)
- APM captures automatically: stack trace, URL, params, user, timing
- During incident: single source of truth for each error
- Engineers see clean, deduplicated error stream

**With manual logging (anti-pattern):**
- One exception generates TWO separate entries (manual log + APM event)
- Backtrace duplicated: once in logs, once in APM
- During incident: engineers waste time correlating manual log with APM event, thinking it's 2 errors
- Log spam: every exception creates 2+ log lines with identical information
- Zero value added beyond what APM captures automatically

---

## References

- [Rails Semantic Logger](https://logger.rocketjob.io/)
