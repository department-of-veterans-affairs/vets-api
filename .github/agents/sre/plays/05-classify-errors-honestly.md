---
id: classify-errors
title: Match status codes to the source (4xx vs 5xx)
version: 2
severity: CRITICAL
category: http-status
tags:
- error-classification
- 4xx-vs-5xx
- who-fixes-it
- http-status
- decision-tree
language: ruby
---

<!--
<agent_play>

  <context>
    When a NoMethodError is caught by a bare rescue and returns 422,
    metrics incorrectly count a server bug as a client error, and the
    team investigates a "validation failure" that does not exist. A
    database outage that returns 422 tells the client their data is
    invalid, when in reality the infrastructure has failed and the
    client can do nothing to fix it. A BGS timeout that returns 422
    causes the client to retry with the same data, which will never help
    because the upstream service is timing out. Dashboards show rising
    client errors, but the actual problems are our bugs, our database,
    and upstream timeouts, so the wrong team investigates with the wrong
    fix.
  </context>

  <applies_to>
    <glob>app/controllers/**/*.rb</glob>
    <glob>modules/*/app/controllers/**/*.rb</glob>
    <glob>lib/**/*.rb</glob>
    <glob>app/sidekiq/**/*.rb</glob>
  </applies_to>

  <related_plays>
    <play id="handle-401-token-ownership" relationship="complementary" />
    <play id="handle-403-permission" relationship="complementary" />
    <play id="map-upstream-network-errors" relationship="complementary" />
  </related_plays>

  <retrieval_triggers>
    <trigger>NoMethodError caught and returned as 422 client error</trigger>
    <trigger>database error returned as 422 instead of 500</trigger>
    <trigger>upstream timeout returned as 422 instead of 504</trigger>
    <trigger>who fixes this determines 4xx vs 5xx status code</trigger>
    <trigger>bare rescue returns client error for server failure</trigger>
    <trigger>error classification decision tree</trigger>
  </retrieval_triggers>

  <detection>
    <pattern name="bare_rescue_returning_422" confidence="high">
      <signature>rescue\s*=>\s*e.*\n.*raise.*UnprocessableEntity</signature>
      <description>
        Bare rescue (`rescue => e`) that catches ALL exceptions and
        re-raises as UnprocessableEntity (422). This maps every
        failure mode — including our own bugs (NoMethodError),
        database errors, and upstream timeouts — as a client
        validation error. High confidence because bare rescue + 422
        always indicates incorrect error classification.
      </description>
      <example>rescue =&gt; e\n  raise Common::Exceptions::UnprocessableEntity</example>
      <example>rescue =&gt; e\n  raise Common::Exceptions::UnprocessableEntity.new(detail: 'Could not process')</example>
    </pattern>
    <pattern name="catch_all_then_422" confidence="medium">
      <signature>rescue.*\n.*raise.*422</signature>
      <description>
        Catches exceptions and raises a 422 status code. Medium
        confidence because the rescue clause may specify appropriate
        exception classes. Check whether the rescue targets only
        validation errors or catches broadly.
      </description>
      <example>rescue StandardError =&gt; e\n  render json: error, status: 422</example>
      <example>rescue =&gt; e\n  raise ActionController::UnprocessableEntity</example>
    </pattern>
    <pattern name="broad_rescue_to_unprocessable_entity" confidence="medium">
      <signature>rescue\s+.*Error.*\n.*raise.*UnprocessableEntity</signature>
      <description>
        Catches a broad error class and raises UnprocessableEntity
        without filtering to only validation-specific types. Medium
        confidence because the rescue may name a specific enough error
        class — read surrounding code to confirm whether it catches
        only client validation errors or also infrastructure failures.
      </description>
      <example>rescue StandardError =&gt; e\n  raise Common::Exceptions::UnprocessableEntity</example>
      <example>rescue RuntimeError =&gt; e\n  raise Common::Exceptions::UnprocessableEntity.new(detail: e.message)</example>
    </pattern>
    <heuristic>
      A rescue block that catches broadly and raises
      UnprocessableEntity (422) is a strong signal of
      misclassification. The "who fixes it" question is key: if the
      rescue can catch NoMethodError, database errors, or upstream
      timeouts, those are NOT client errors and should not return
      422.
    </heuristic>
    <heuristic>
      A controller or service method that calls external services
      (BGS, MPI, Faraday) and has a single rescue clause returning
      422 likely conflates upstream/internal failures with client
      validation errors. Check whether the rescue distinguishes
      between validation exceptions and infrastructure exceptions.
    </heuristic>
    <false_positive>
      A rescue clause that catches only specific validation
      exception classes (e.g., `rescue ValidationError,
      ArgumentError => e`) and raises 422 is correct. The key test
      is whether the caught exceptions are exclusively client-data
      problems that the client can fix by changing their request.
    </false_positive>
    <false_positive>
      A rescue clause in a controller that catches
      `ActiveRecord::RecordInvalid` and returns 422 is acceptable.
      Record validation failures are client data issues when the
      validations enforce business rules on client-provided data.
    </false_positive>
  </detection>

  <rules>
    <rule enforcement="must">
      Choose HTTP status code by ownership of fix: 4xx when client
      must change their request, 5xx when our code or upstream is at
      fault.
    </rule>
    <rule enforcement="must_not">
      Never rebrand 5xx errors as 4xx to quiet dashboards — this
      hides real problems from the team that can fix them.
    </rule>
    <rule enforcement="must_not">
      Never rebrand client 4xx as 5xx to get attention — this
      creates false alarms and alert fatigue.
    </rule>
    <rule enforcement="must">
      When transforming an upstream status, preserve the original by
      including meta.upstream_status and meta.upstream_service on
      the error.
    </rule>
    <rule enforcement="must">
      Catch only specific validation exceptions before returning 422
      — never use bare rescue with UnprocessableEntity.
    </rule>
    <rule enforcement="should">
      Ask "Who fixes this?" before choosing a status code family:
      client (4xx), our team (500), upstream (502/503/504).
    </rule>
    <rule enforcement="verify">
      APM shows code bugs as 500 (not 4xx)
    </rule>
    <rule enforcement="verify">
      Metrics accurately split: client errors vs our bugs vs
      upstream issues
    </rule>
    <rule enforcement="verify">
      Status code matches "who fixes it" (client/us/upstream)
    </rule>
  </rules>

  <investigate_before_answering>
    <step>Read the full method containing the rescue block to understand what code is protected and what exception types it can raise.</step>
    <step>Identify which exceptions represent client data problems (should be 422) vs our code bugs (should be 500) vs upstream failures (should be 502/503/504).</step>
    <step>Determine whether typed validation exceptions already exist in the module's namespace (check for `ValidationError` or similar classes).</step>
    <step>Check if the method calls external services (BGS, MPI, Faraday) whose failures should NOT be classified as client errors.</step>
    <step>Verify that `Common::Exceptions::UnprocessableEntity`, `InternalServerError`, and gateway exceptions are available in the module's namespace. Do not suggest returning 422 for any exception type that represents a server-side or upstream failure. The "who fixes it" question determines the status family.</step>
  </investigate_before_answering>

  <severity_assessment>
    <critical>bare rescue returns 422 in code that processes veteran claims,
benefits, or health data</critical>
    <critical>all exception types mapped to client error (4xx) causing
complete misattribution in metrics</critical>
    <high>broad rescue returns 422 in service layer calling external
APIs (BGS, MPI, Lighthouse)</high>
    <medium>rescue returns 422 but catches a reasonably narrow set of
exceptions that could be narrowed further</medium>
  </severity_assessment>

  <default_to_action>
    When you detect error misclassification, provide a fix that
    splits validation exceptions (422) from infrastructure
    exceptions (500/502/503/504) using the "who fixes it" rule.
  </default_to_action>

  <verify>
    <command description="No bare rescue returning UnprocessableEntity in changed file">
      grep -On 'rescue\s*=>\s*e.*\n.*UnprocessableEntity' {{file_path}} &amp;&amp; exit 1 || exit 0
    </command>
    <command description="No broad rescue returning 422 remains">
      grep -On 'rescue\s+(StandardError|RuntimeError|Exception).*\n.*UnprocessableEntity' {{file_path}} &amp;&amp; exit 1 || exit 0
    </command>
    <command description="Run specs for changed file">
      bundle exec rspec {{spec_path}}
    </command>
    <command description="RuboCop passes for changed file">
      bundle exec rubocop {{file_path}}
    </command>
  </verify>

  <pr_comment_template>
    **Classify errors honestly (4xx vs 5xx)** | `CRITICAL`

    `{{file_path}}:{{line_number}}` — {{one_line_violation_description}}

    **Why this matters:** Returning 422 (client error) for server-side failures
    means metrics blame clients for our bugs. Dashboards show "validation errors"
    when the actual problems are our code bugs, database failures, or upstream
    timeouts. The team that should fix the problem never gets paged.

    **Ask: "Who fixes this?"**
    - Client's bad input -> 422 (client error)
    - Our code bug -> 500 (server error)
    - Upstream timeout -> 504 (gateway timeout)

    **Suggested fix:**
    ```ruby
    {{suggested_code}}
    ```

    **Verify:**
    - [ ] Rescue catches only validation exceptions (not bare rescue)
    - [ ] NoMethodError propagates as 500 (not 422)
    - [ ] Upstream timeouts propagate as 504 (not 422)
    - [ ] Cause chain preserved with `cause: e`
    - [ ] Metrics correctly split client errors vs server errors

    [Play: Match Status Codes to the Source](plays/match-status-codes-to-the-source.md)
  </pr_comment_template>

</agent_play>
-->

# Match Status Codes to the Source (4xx vs 5xx)

Before choosing an HTTP status code, ask "Who fixes this?" — the client (4xx), our team (500), or an upstream service (502/503/504). Never rebrand server failures as client errors to quiet dashboards.

> [!CAUTION]
> Returning 422 for a `NoMethodError` hides your bugs from APM — metrics show "validation failures" while real server errors go undetected.

## Why It Matters

When a bare rescue catches a `NoMethodError` and returns 422, metrics incorrectly count your bug as a client validation error. The product team investigates "validation failures" that don't exist. A database outage that returns 422 tells the client their data is invalid when the infrastructure has failed. A BGS timeout that returns 422 causes the client to retry with the same data — it will never help because the upstream service is timing out.

## Guidance

Choose status codes by ownership: 4xx when the client must change their request, 5xx when your code or an upstream service is at fault. Catch only specific validation exceptions (like `ArgumentError` or `ActiveRecord::RecordInvalid`) before returning 422. Let `NoMethodError`, database errors, and upstream timeouts propagate as 5xx.

### Do

- `rescue ValidationError, ArgumentError => e` then raise 422 — client can fix their data
- Let `NoMethodError` propagate — our bug, should be 500
- Let `Faraday::TimeoutError` propagate — upstream issue, should be 504

### Don't

- `rescue => e` then raise 422 — catches everything, blames client for our bugs
- Rebrand 5xx as 4xx to quiet dashboards — hides real problems
- Rebrand 4xx as 5xx for attention — creates false alarms

## Anti-Patterns

### Dependents Benefits UserData

**Source:** [modules/dependents_benefits/lib/dependents_benefits/user_data.rb:50-54](https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/modules/dependents_benefits/lib/dependents_benefits/user_data.rb#L50-L54)

```ruby
def initialize(user, claim_data)
  @first_name = user.first_name.presence || claim_data.dig('veteran_information', 'full_name', 'first')
  # ... more assignments ...
rescue => e  # Bare rescue catches ALL errors
  monitor.track_user_data_error('DependentsBenefits::UserData#initialize error',
                                'user_hash.failure', error: e)
  raise Common::Exceptions::UnprocessableEntity.new(detail: 'Could not initialize user data')
  # Returns 422 (client error) for ALL failures — even our bugs!
end
```

**Problem:** Bare `rescue => e` catches `NoMethodError` from typos, database errors, and upstream timeouts. Returns 422 for all failure modes — metrics count our bugs as client validation errors, and the wrong team investigates.

**Corrected:**

```ruby
def initialize(user, claim_data)
  @first_name = user.first_name.presence || claim_data.dig('veteran_information', 'full_name', 'first')
  # ... more assignments ...
  validate_required_fields!
rescue ArgumentError, ValidationError => e
  monitor.track_user_data_error('Validation failed', 'user_hash.validation_error', error: e)
  raise Common::Exceptions::UnprocessableEntity.new(
    code: 'INVALID_USER_DATA',
    detail: e.message,
    cause: e
  )
# Don't catch NoMethodError, BGS::ServiceError, etc. — let them raise as 500s
end
```

## Reference

### Classification Matrix

| HTTP | Meaning | Who Fixes? | Auto-Retry? | Example |
|------|---------|------------|-------------|---------|
| **400** | Bad Request | Client developer | No | Malformed JSON, invalid parameter type |
| **401** | Unauthorized | Depends on token ownership | Sometimes | User token expired, service account invalid |
| **403** | Forbidden | Admin/Product | No | Lacks permission, account locked |
| **404** | Not Found | Client or Product | No | Invalid claim ID, resource not created |
| **409** | Conflict | Client | Manual | Duplicate submission, version mismatch |
| **410** | Gone | N/A (permanent) | Never | Appointment cancelled, form withdrawn |
| **422** | Unprocessable Entity | Client (fix data) | No | Email format invalid, date in past |
| **429** | Too Many Requests | Client | Yes | Rate limit exceeded |
| **500** | Internal Server Error | Our team | Sometimes | Unhandled exception, DB connection failed |
| **502** | Bad Gateway | Upstream service | Yes | Upstream returned invalid response |
| **503** | Service Unavailable | Infrastructure/Upstream | Yes | Circuit breaker open, upstream down |
| **504** | Gateway Timeout | Upstream performance | Yes | Upstream too slow, network latency |

### Decision Tree

```text
Problem with the request?
├─ NO → Problem in an upstream service?
│  ├─ NO → 500 Internal Server Error (our bug)
│  └─ YES → Is upstream responding?
│       ├─ NO (down) → 503 Service Unavailable
│       ├─ NO (slow) → 504 Gateway Timeout
│       └─ YES (bad response) → 502 Bad Gateway
│
└─ YES → Is the user authenticated?
    ├─ NO → 401 Unauthorized
    └─ YES → Is the user authorized?
        ├─ NO → 403 Forbidden (or 404 to hide existence)
        └─ YES → Rate limit exceeded?
            ├─ YES → 429 Too Many Requests
            └─ NO → Resource exists?
                ├─ NO → 404 Not Found (or 410 Gone)
                └─ YES → State conflict?
                    ├─ YES → 409 Conflict
                    └─ NO → Valid data?
                        ├─ NO → 400 (syntax) or 422 (business rules)
                        └─ YES → 200 OK
```

## References

- [RFC 7231 Section 6](https://tools.ietf.org/html/rfc7231#section-6)
- Related: [Handle 401 Authentication Errors](06-handle-401-token-ownership.md)
- Related: [Handle 403 Authorization Errors](07-handle-403-permission-vs-existence.md)
