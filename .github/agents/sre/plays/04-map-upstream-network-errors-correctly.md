---
id: map-upstream-network-errors
title: Don't let all upstream network errors fall through as 500 errors
version: 2
severity: CRITICAL
category: http-status
tags:
- upstream-errors
- network-mapping
- 502
- 503
- 504
- faraday
language: ruby
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

  <retrieval_triggers>
    <trigger>all upstream errors mapped to 500 internal server error</trigger>
    <trigger>timeout returns 500 instead of 504 gateway timeout</trigger>
    <trigger>connection failure returns 500 instead of 503</trigger>
    <trigger>cannot distinguish our bugs from upstream failures</trigger>
    <trigger>Faraday errors all become InternalServerError</trigger>
  </retrieval_triggers>

  <detection>
    <pattern name="faraday_error_to_internal_server_error" confidence="high">
      <signature>rescue\s+Faraday::\w+.*\n.*InternalServerError</signature>
      <description>
        Catches a Faraday exception (any subclass) and re-raises it as
        InternalServerError (500). This maps all upstream network
        failures (timeouts, connection errors, server errors) to 500,
        which blames our team for upstream problems. High confidence
        because upstream network errors should never become 500.
      </description>
      <example>rescue Faraday::ClientError =&gt; e\n  raise Common::Exceptions::InternalServerError</example>
      <example>rescue Faraday::ServerError =&gt; e\n  raise Common::Exceptions::InternalServerError, exception: e</example>
    </pattern>
    <pattern name="faraday_blanket_catch" confidence="medium">
      <signature>rescue\s+Faraday::ClientError,\s*Faraday::ServerError</signature>
      <description>
        Catches both Faraday::ClientError and Faraday::ServerError in
        a single rescue clause without distinguishing between them.
        This conflates timeouts, connection failures, and server
        errors into a single code path. Medium confidence because the
        handler body determines whether it is a violation — it may map
        to different statuses downstream.
      </description>
      <example>rescue Faraday::ClientError, Faraday::ServerError =&gt; e</example>
    </pattern>
    <pattern name="upstream_to_500_with_exception" confidence="high">
      <signature>raise.*InternalServerError.*exception:\s*e</signature>
      <description>
        Explicitly maps an upstream exception to 500 using the
        `exception:` parameter. This pattern passes the original
        exception for logging but still returns 500 to the client,
        hiding whether the failure was a timeout, connection error, or
        server error. High confidence because upstream errors should
        map to 502/503/504, not 500.
      </description>
      <example>raise Common::Exceptions::InternalServerError, exception: e</example>
      <example>raise Common::Exceptions::InternalServerError.new(exception: e)</example>
    </pattern>
    <heuristic>
      A rescue block that catches any Faraday exception and raises a
      single non-gateway HTTP error (especially 500) is a strong
      signal of incorrect upstream error mapping. Check whether the
      handler distinguishes between timeout, connection, and server
      errors.
    </heuristic>
    <heuristic>
      A service class or controller action that makes HTTP calls via
      Faraday but has only one rescue clause for all Faraday errors
      likely conflates upstream failure modes. Look for separate
      rescue clauses for TimeoutError, ConnectionFailed, and
      ServerError.
    </heuristic>
    <false_positive>
      A rescue block that catches `Faraday::ClientError` (4xx
      responses from upstream) and maps to a specific client error
      (e.g., 404 or 422) is acceptable. Client errors from upstream
      may legitimately translate to client errors in our API when
      the upstream is proxying client data.
    </false_positive>
    <false_positive>
      A generic Faraday rescue block inside a retry wrapper that re-
      raises after exhausting retries. The outer retry logic may
      handle the distinction, and the inner catch is only for retry
      control flow.
    </false_positive>
  </detection>

  <rules>
    <rule enforcement="must">
      Catch network-level failures (timeouts, connection/DNS, TLS,
      malformed responses) and map each to a specific 5xx status
      code.
    </rule>
    <rule enforcement="must_not">
      Never map upstream network errors to 500 Internal Server Error
      — 500 means our code is broken, not that an upstream service
      failed.
    </rule>
    <rule enforcement="must">
      Map connection/DNS failures to 503 Service Unavailable,
      timeouts to 504 Gateway Timeout, and upstream server errors to
      502 Bad Gateway.
    </rule>
    <rule enforcement="must_not">
      Never catch all Faraday errors with a single rescue clause
      that returns one status code — each failure mode requires a
      distinct HTTP status.
    </rule>
    <rule enforcement="should">
      Include `meta.upstream_status` when wrapping upstream server
      errors as 502 so dashboards can show who is at fault.
    </rule>
    <rule enforcement="verify">
      Timeouts return 504 (not 500)
    </rule>
    <rule enforcement="verify">
      Connection failures return 503 (not 500)
    </rule>
    <rule enforcement="verify">
      Upstream 500s return 502 with upstream status preserved
    </rule>
    <rule enforcement="verify">
      Metrics separate our bugs (500) from upstream issues
      (502/503/504)
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

  <default_to_action>
    When you detect upstream errors mapped to 500, provide the
    split rescue pattern: TimeoutError to 504, ConnectionFailed to
    503, ServerError to 502 with meta.upstream_status.
  </default_to_action>

  <verify>
    <command description="No Faraday errors mapped to InternalServerError in changed file">
      grep -On 'rescue\s+Faraday::.*\n.*InternalServerError' {{file_path}} &amp;&amp; exit 1 || exit 0
    </command>
    <command description="No blanket Faraday catch without distinction">
      grep -On 'rescue\s+Faraday::ClientError,\s*Faraday::ServerError' {{file_path}} &amp;&amp; exit 1 || exit 0
    </command>
    <command description="Run specs for changed file">
      bundle exec rspec {{spec_path}}
    </command>
    <command description="RuboCop passes for changed file">
      bundle exec rubocop {{file_path}}
    </command>
  </verify>

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

    [Play: Map Upstream Network Errors Correctly](plays/map-upstream-network-errors-correctly.md)
  </pr_comment_template>

</agent_play>
-->

# Map Upstream Network Errors Correctly

When an upstream service times out or fails, map each failure mode to the correct gateway status code (502/503/504) instead of letting everything fall through as 500.

> [!CAUTION]
> Mapping all upstream errors to 500 blames your team for upstream failures — metrics, alerts, and on-call pages fire on the wrong team.

## Why It Matters

When you catch a Faraday timeout and raise `InternalServerError`, metrics count it as your bug. Alerts page your team for an upstream service's slow response. The client sees 500 and won't retry because HTTP treats 500 as non-retryable — but a 504 would signal a gateway timeout and trigger automatic retries. SRE investigates your code and wastes hours when the actual problem is an upstream DNS failure that should have returned 503.

## Guidance

Split your Faraday rescue blocks by failure mode: `TimeoutError` maps to 504 Gateway Timeout, `ConnectionFailed` maps to 503 Service Unavailable, and `ServerError` maps to 502 Bad Gateway. Include `meta.upstream_status` on 502 responses so dashboards show who's at fault.

### Do

- `rescue Faraday::TimeoutError => e` then raise 504 — upstream was too slow
- `rescue Faraday::ConnectionFailed => e` then raise 503 — upstream is unreachable
- `rescue Faraday::ServerError => e` then raise 502 with `meta.upstream_status` — upstream broke

### Don't

- `rescue Faraday::ClientError, Faraday::ServerError => e` in one clause — conflates failure modes
- `raise InternalServerError, exception: e` — 500 means our code is broken, not upstream

## Anti-Patterns

### Travel Pay Claims Controller

**Source:** [modules/travel_pay/app/controllers/travel_pay/v0/claims_controller.rb:66-67](https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/modules/travel_pay/app/controllers/travel_pay/v0/claims_controller.rb#L66-L67)

```ruby
rescue Faraday::ClientError, Faraday::ServerError => e
  raise Common::Exceptions::InternalServerError, exception: e
  # Maps ALL Faraday errors to 500 (our fault)
  # Should distinguish: timeout→504, connection→503, server→502
end
```

**Problem:** Catches both `ClientError` and `ServerError` in one clause and maps all upstream failures to 500. Metrics blame our team. Clients see 500 (non-retryable) instead of 504 (retryable) for upstream timeouts.

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

## References

- [RFC 7231 Section 6.6](https://tools.ietf.org/html/rfc7231#section-6.6)
