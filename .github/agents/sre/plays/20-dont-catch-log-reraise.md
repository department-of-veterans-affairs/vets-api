---
id: dont-catch-log-reraise
title: Don't catch, log, and re-raise (no double handling)
severity: HIGH
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

  <rules>
    <rule enforcement="must">
      Catch exceptions only when adding meaningful context or
      converting to a typed exception — if you are just logging
      and re-raising, APM already captures everything.
    </rule>
    <rule enforcement="should">
      Emit metrics (StatsD counters) for retry attempts instead of
      log lines.
    </rule>
  </rules>

  <investigate_before_answering>
    <step>**Meaningful context check (MANDATORY EXCLUSION).** Read the full rescue block and identify every piece of data in the log call. Compare each field against what APM automatically captures (exception class, message, backtrace, request params, user context, timing). If the log includes ANY business-context identifier that APM does NOT have — such as `poa_request_id`, `claim_id`, `appeal_id`, `veteran_icn`, upstream HTTP status, or other domain-specific correlation IDs — then this is NOT a catch-log-reraise violation. The log adds value that APM cannot provide. Do NOT flag it. Instead, if the log level is wrong (e.g., ERROR for a retryable failure), flag that under Play 21 instead.</step>
    <step>**Check for side effects beyond logging.** If the rescue block performs meaningful work (e.g., `update_status!`, database writes, metric emission, notification) in addition to logging, the rescue block is justified. Only the redundant LOG LINE is the issue, not the rescue block itself. Describe the finding accurately: "the log is redundant but the rescue block is needed for [side effect]."</step>
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
    <false_positive>rescue block that logs business-context IDs not
available in APM (poa_request_id, claim_id, upstream HTTP status,
etc.) before re-raising — the log adds correlation value that APM
traces do not automatically capture</false_positive>
    <false_positive>rescue block that performs side effects (status
updates, DB writes, notifications) in addition to logging — the
rescue is justified; only the log line may be redundant</false_positive>
  </severity_assessment>

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
    - [ ] If wrapping, cause chain preserved (Ruby sets `$!.cause` automatically within rescue)

    [Play: Don't catch, log, and re-raise](20-dont-catch-log-reraise.md)
  </pr_comment_template>

</agent_play>
-->

### Do

- Catch only when adding meaningful context or converting to a typed exception:

  ```ruby
  rescue CemeteryService::UpstreamError
    raise Common::Exceptions::ServiceUnavailable.new(
      detail: 'NCA cemetery database unavailable'
    )
    # Ruby automatically sets $!.cause to the caught UpstreamError
  end
  ```

- Wrap in a new typed exception when adding domain context:

  ```ruby
  rescue Faraday::TimeoutError
    raise Common::Exceptions::GatewayTimeout.new(detail: 'Upstream service timed out')
    # Ruby preserves the cause chain automatically within rescue blocks
  end
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

```ruby
rescue => e
  Rails.logger.error "Cemetery controller error: #{e.message}"
  Rails.logger.error e.backtrace.join("\n")  # Manual backtrace logging
  render json: { error: 'Unable to load cemetery data' }, status: :internal_server_error
  # APM ALSO captures this exception with backtrace automatically
end
```

#### Golden Pattern

```ruby
# Let APM capture it naturally - no rescue needed
def index
  @cemeteries = CemeteryService.all
  render json: @cemeteries
  # Exception propagates to Rails error handler → APM captures automatically
end

# OR if adding meaningful context:
rescue CemeteryService::UpstreamError
  raise Common::Exceptions::ServiceUnavailable.new(
    detail: 'NCA cemetery database unavailable'
  )
  # Ruby automatically preserves cause chain within rescue blocks
end
```
