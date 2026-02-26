---
id: map-upstream-network-errors
title: Don't let all upstream network errors fall through as 500 errors
severity: CRITICAL
---

<!--
<agent_play>

  <context>
    When an upstream timeout falls through as a generic 500, metrics
    blame our team and alerts page us, even though the actual problem is
    the upstream service's slow response. The client sees 500 and will
    not retry because the HTTP spec treats 500 as non-retryable, but a
    504 would signal a gateway timeout and trigger automatic retries.
    APM shows generic 500 errors with no way to distinguish our code
    bugs from upstream timeouts, requiring manual log grep to identify
    the root cause. SRE investigates our code and wastes hours when the
    actual problem is an upstream DNS failure that should have returned
    503.
  </context>

  <applies_to>
    <glob>app/controllers/**/*.rb</glob>
    <glob>modules/*/app/controllers/**/*.rb</glob>
    <glob>lib/**/*.rb</glob>
    <glob>app/services/**/*.rb</glob>
    <glob>modules/*/app/services/**/*.rb</glob>
  </applies_to>

  <related_plays>
    <play id="classify-errors" relationship="prerequisite" />
    <play id="preserve-cause-chains" relationship="complementary" />
  </related_plays>

  <rules>
    <rule enforcement="must">
      Map each upstream network failure to a specific HTTP status:
      timeouts to 504 Gateway Timeout, connection/DNS failures to
      503 Service Unavailable, upstream server errors to 502 Bad
      Gateway. Reserve 500 for our own code bugs.
    </rule>
    <rule enforcement="should">
      Include `meta.upstream_status` when wrapping upstream server
      errors as 502 so dashboards can show who is at fault.
    </rule>
  </rules>

  <investigate_before_answering>
    <step>Read the full method containing the rescue block to understand which Faraday methods are called and what upstream services are contacted.</step>
    <step>Identify which Faraday exception types the upstream call can raise — TimeoutError, ConnectionFailed, ServerError, ClientError, etc.</step>
    <step>Check whether the code is in a controller (boundary) or service layer. Controllers should map to HTTP status codes. Service layers may need to raise module-specific exceptions that controllers then translate.</step>
    <step>Verify that `Common::Exceptions::GatewayTimeout`, `ServiceUnavailable`, and `BadGateway` are available in the module's namespace.</step>
    <step>Check if the upstream response object (`e.response`) is available for the caught exception type — `Faraday::ConnectionFailed` has no response. Do not suggest adding `meta.upstream_status` for exceptions that lack a response object (e.g., TimeoutError, ConnectionFailed).</step>
  </investigate_before_answering>

  <severity_assessment>
    <critical>all upstream Faraday errors mapped to 500 in a controller
handling veteran-facing requests</critical>
    <critical>upstream timeouts return 500 causing incorrect alert routing
and client retry failure</critical>
    <high>blanket Faraday catch in service layer without distinguishing
timeout from connection failure</high>
    <medium>upstream errors mapped to correct gateway status but missing
meta.upstream_status</medium>
  </severity_assessment>

  <pr_comment_template>
    **Don't let all upstream network errors fall through as 500 errors** | `CRITICAL`

    `{{file_path}}:{{line_number}}` — {{one_line_violation_description}}

    **Why this matters:** Mapping all upstream errors to 500 blames our team
    for upstream failures. Metrics, alerts, and on-call pages fire on the
    wrong team. Clients see 500 (non-retryable) instead of 504 (retryable)
    for transient upstream failures. APM cannot distinguish our code bugs
    from upstream timeouts or connection failures.

    **Suggested fix:**
    ```ruby
    rescue Faraday::TimeoutError => e
      raise Common::Exceptions::GatewayTimeout.new(cause: e)  # 504
    rescue Faraday::ConnectionFailed => e
      raise Common::Exceptions::ServiceUnavailable.new(cause: e)  # 503
    rescue Faraday::ServerError => e
      raise Common::Exceptions::BadGateway.new(
        detail: 'Upstream service error',
        meta: { upstream_status: e.response[:status] },
        cause: e
      )
    end
    ```

    **Verify:**
    - [ ] Timeouts return 504 (not 500)
    - [ ] Connection failures return 503 (not 500)
    - [ ] Upstream server errors return 502 with `meta.upstream_status`
    - [ ] Cause chain preserved with `cause: e`
    - [ ] Metrics separate our bugs (500) from upstream issues (502/503/504)

    [Play: Map Upstream Network Errors Correctly](04-map-upstream-network-errors-correctly.md)
  </pr_comment_template>

</agent_play>
-->

### Do

- `rescue Faraday::TimeoutError => e` then raise 504 — upstream was too slow
- `rescue Faraday::ConnectionFailed => e` then raise 503 — upstream is unreachable
- `rescue Faraday::ServerError => e` then raise 502 with `meta.upstream_status` — upstream broke

### Don't

- `rescue Faraday::ClientError, Faraday::ServerError => e` in one clause — conflates failure modes
- `raise InternalServerError, exception: e` — 500 means our code is broken, not upstream

## Anti-Patterns

### Travel Pay Claims Controller

```ruby
rescue Faraday::ClientError, Faraday::ServerError => e
  raise Common::Exceptions::InternalServerError, exception: e
  # Maps ALL Faraday errors to 500 (our fault)
  # Should distinguish: timeout→504, connection→503, server→502
end
```

**Corrected:**

```ruby
rescue Faraday::TimeoutError => e
  raise Common::Exceptions::GatewayTimeout.new(cause: e)  # 504

rescue Faraday::ConnectionFailed => e
  raise Common::Exceptions::ServiceUnavailable.new(cause: e)  # 503

rescue Faraday::ServerError => e
  raise Common::Exceptions::BadGateway.new(
    detail: 'Upstream service error',
    meta: { upstream_status: e.response[:status] },
    cause: e
  )
end
```
