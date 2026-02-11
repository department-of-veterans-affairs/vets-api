---
id: handle-401-token-ownership
title: Handle 401 Authentication Errors (Token Ownership Matters!)
version: 1
severity: CRITICAL
category: http-status
tags:
- 401
- authentication
- token-ownership
- service-account
- credentials
language: ruby
---

<!--
<agent_play>

  <context>
    When our service account credentials fail, returning 401 makes the
    client think they failed, so metrics blame the client and the wrong
    team gets paged. The client retries with a refresh token, but that
    will never work because our configuration is broken, not theirs.
    Dashboards show "authentication errors" and the team investigates
    user auth, when the actual problem is that our MPI credentials have
    expired. A 401 means "client, fix your credentials" while a 500
    means "we need to fix this," so getting the code wrong misdirects
    the entire incident response.
  </context>

  <applies_to>
    <glob>app/controllers/**/*.rb</glob>
    <glob>modules/*/app/controllers/**/*.rb</glob>
    <glob>lib/**/*.rb</glob>
    <glob>modules/*/lib/**/*.rb</glob>
  </applies_to>

  <related_plays>
    <play id="handle-403-permission" relationship="complementary" />
    <play id="classify-errors" relationship="complementary" />
  </related_plays>

  <retrieval_triggers>
    <trigger>upstream 401 passed through blindly to client</trigger>
    <trigger>service account failure returns 401 instead of 500</trigger>
    <trigger>whose credentials failed determines status code</trigger>
    <trigger>authentication error misattributed to client</trigger>
    <trigger>token ownership check before returning 401</trigger>
  </retrieval_triggers>

  <detection>
    <pattern name="blind_401_passthrough" confidence="high">
      <signature>rescue\s+.*UnauthorizedError.*\n.*raise.*Unauthorized</signature>
      <description>
        Catches an upstream UnauthorizedError and immediately re-
        raises as Unauthorized (401) without checking whose
        credentials failed. If the upstream 401 was caused by our
        service account credentials being invalid, this incorrectly
        blames the client. The rescue must distinguish between user
        token failures (401) and service account failures (500) before
        choosing the status code.
      </description>
      <example>rescue Faraday::UnauthorizedError =&gt; e\n  raise Common::Exceptions::Unauthorized.new(...)</example>
      <example>rescue Common::Client::Errors::ClientError =&gt; e\n  raise Common::Exceptions::Unauthorized</example>
    </pattern>
    <pattern name="upstream_auth_raise" confidence="medium">
      <signature>raise.*Unauthorized.*upstream.*auth</signature>
      <description>
        Raises an Unauthorized exception with a message referencing
        upstream authentication. Medium confidence because the mention
        of "upstream" suggests the developer is aware the error came
        from an external service, but may not be checking whether the
        upstream failure was caused by user credentials or our service
        account. Needs surrounding code inspection.
      </description>
      <example>raise Common::Exceptions::Unauthorized.new(detail: "Upstream authentication failed")</example>
      <example>raise Unauthorized, "upstream auth error"</example>
    </pattern>
    <pattern name="faraday_unauthorized_no_service_check" confidence="high">
      <signature>rescue\s+Faraday::UnauthorizedError</signature>
      <description>
        Catches Faraday::UnauthorizedError (HTTP 401 from an upstream
        service) without a conditional check for service account vs
        user token authentication. Any rescue of this exception must
        include a branch that checks
        `using_service_account_credentials?` or equivalent logic
        before deciding the response status code.
      </description>
      <example>rescue Faraday::UnauthorizedError =&gt; e</example>
      <example>rescue Faraday::UnauthorizedError</example>
    </pattern>
    <heuristic>
      A rescue block that catches Faraday::UnauthorizedError or a
      similar upstream 401 exception and raises
      Common::Exceptions::Unauthorized without any conditional
      branching is a strong signal that all upstream 401s are
      blindly passed through. Check for if/else or case statements
      that differentiate user tokens from service account
      credentials.
    </heuristic>
    <heuristic>
      Methods that call external services (MPI, EVSS, BGS,
      Lighthouse) using service account credentials and contain a
      rescue for 401 errors are high-priority candidates for this
      anti-pattern. Service account failures should always produce
      500, not 401.
    </heuristic>
    <heuristic>
      A rescue block that catches 401 errors and does not include
      `meta.auth_type` in the raised exception suggests the
      developer did not consider token ownership. The absence of
      auth_type metadata means monitoring cannot distinguish user
      token failures from service account failures.
    </heuristic>
    <false_positive>
      A rescue for Faraday::UnauthorizedError that explicitly checks
      whether the request used user-provided credentials (e.g.,
      OAuth token from the session) and only raises 401 in that case
      is not a violation. The key is that the code demonstrates
      awareness of token ownership before choosing the status code.
    </false_positive>
    <false_positive>
      Controllers that handle direct user login (e.g., sessions
      controller, sign-in endpoints) where the only credentials
      involved are the user's own. In these contexts, a 401 is
      always correct because there are no service account
      credentials involved.
    </false_positive>
  </detection>

  <rules>
    <rule enforcement="must">
      Ask "Whose credentials failed?" before choosing a status code
      for upstream 401 errors.
    </rule>
    <rule enforcement="must">
      Return 500 (not 401) when our service account credentials fail
      upstream — this is our configuration error, not the client's
      authentication failure.
    </rule>
    <rule enforcement="must">
      Include `meta.auth_type` ("user_token" or "service_account")
      on all authentication-related exceptions to enable monitoring
      to distinguish failure modes.
    </rule>
    <rule enforcement="must">
      Preserve upstream context with `meta.upstream_status: 401`,
      `meta.upstream_service`, and `cause: e`.
    </rule>
    <rule enforcement="must_not">
      Never pass through all upstream 401 errors blindly as 401 to
      clients — check token ownership first.
    </rule>
    <rule enforcement="should">
      Include actionable detail messages: "Session expired. Please
      sign in again." for user tokens, "Service authentication
      configuration error" for service accounts.
    </rule>
    <rule enforcement="verify">
      APM can distinguish user auth failures from service account
      config errors
    </rule>
    <rule enforcement="verify">
      Service account failures return 500 (not 401)
    </rule>
    <rule enforcement="verify">
      Status code matches "whose credentials failed" (user/service
      account)
    </rule>
  </rules>

  <investigate_before_answering>
    <step>Read the full method containing the rescue block to understand what upstream service is being called and what credentials are used for the request.</step>
    <step>Determine whether the upstream call uses user-provided credentials (OAuth token from session) or service account credentials (configured API keys, service accounts from environment variables or credential stores).</step>
    <step>Check if the service client configuration includes service account credentials (look for API key settings, service account configs, or client certificate configurations in the service wrapper).</step>
    <step>Identify whether the module already has helper methods for checking credential type (e.g., `using_service_account_credentials?`, `service_auth?`).</step>
    <step>Check what meta fields are already included on the raised exception to determine what upstream context is preserved. Do not suggest fixes without understanding which credentials the upstream call uses. The correct status code depends entirely on whose credentials failed.</step>
  </investigate_before_answering>

  <severity_assessment>
    <critical>upstream 401 from a service using service account credentials
is passed through as 401 to the client</critical>
    <critical>rescue Faraday::UnauthorizedError raises Unauthorized without
checking credential type</critical>
    <high>401 exception raised without meta.auth_type — cannot
distinguish user token from service account failures</high>
    <high>service account failure returns 401 and monitoring attributes
it to client authentication</high>
    <medium>401 exception missing meta.upstream_service or
meta.upstream_status context</medium>
  </severity_assessment>

  <default_to_action>
    When you detect a blind 401 pass-through, provide the token
    ownership check pattern: branch on credential type, return 500
    for service account failures and 401 for user token failures.
  </default_to_action>

  <verify>
    <command description="No blind 401 pass-through without auth_type check">
      grep -On 'rescue.*UnauthorizedError.*\n.*raise.*Unauthorized' {{file_path}} | grep -v 'auth_type' &amp;&amp; exit 1 || exit 0
    </command>
    <command description="All auth exceptions include meta.auth_type">
      grep -On 'raise.*Unauthorized\|raise.*InternalServerError.*AUTH' {{file_path}} | grep -v 'auth_type' &amp;&amp; exit 1 || exit 0
    </command>
    <command description="Run specs for changed file">
      bundle exec rspec {{spec_path}}
    </command>
    <command description="RuboCop passes for changed file">
      bundle exec rubocop {{file_path}}
    </command>
  </verify>

  <pr_comment_template>
    **Handle 401 Authentication Errors (Token Ownership Matters!)** | `CRITICAL`

    `{{file_path}}:{{line_number}}` — Upstream 401 passed through as 401 without
    checking whose credentials failed. If this service uses service account
    credentials, the 401 should be remapped to 500 (our config error, not client's
    auth failure).

    **Why this matters:** When our service account credentials fail upstream and we
    return 401, the client thinks THEY need to re-authenticate. They refresh their
    token and retry — it still fails. Metrics blame the client. Wrong team gets
    paged. The actual fix requires our team to update service account configuration.

    **Suggested fix:**
    ```ruby
    {{suggested_code}}
    ```

    **Verify:**
    - [ ] Checks whose credentials failed before choosing status code
    - [ ] Service account failures return 500, user token failures return 401
    - [ ] Includes `meta.auth_type` ("user_token" or "service_account")
    - [ ] Preserves upstream context: `meta.upstream_status`, `meta.upstream_service`
    - [ ] Cause chain preserved with `cause: e`

    [Play: Handle 401 Authentication Errors](plays/handle-401-token-ownership.md)
  </pr_comment_template>

  <anti_pattern_sources>
    <source name="Blind Pass-Through" file="inline-example" />
  </anti_pattern_sources>

</agent_play>
-->

# Handle 401 Authentication Errors (Token Ownership Matters!)

When upstream returns 401, ask "Whose credentials failed?" before choosing a status code. User token failures are 401; our service account failures are 500.

> [!CAUTION]
> Passing through all upstream 401s blindly blames the client for our service account misconfiguration — they retry with a new token while the real problem is our config.

## Why It Matters

When your service account credentials fail upstream and you return 401, the client thinks they need to re-authenticate. They refresh their token and retry — it still fails because your configuration is broken, not theirs. Dashboards show "authentication errors" and the team investigates user auth, when the actual problem is that your MPI credentials expired. A 401 means "client, fix your credentials" while a 500 means "we need to fix this" — getting the code wrong misdirects the entire incident response.

## Guidance

Always check whose credentials failed before choosing a status code for upstream 401 errors. If the upstream call used service account credentials (API keys, service accounts from config), return 500 — it's your configuration error. If it used the user's OAuth token, return 401 — the client can refresh and retry. Include `meta.auth_type` on all authentication-related exceptions so monitoring can distinguish the two.

### Do

- Check `using_service_account_credentials?` before choosing status code
- Return 500 with `meta.auth_type: "service_account"` for service account failures
- Return 401 with `meta.auth_type: "user_token"` for user token failures
- Include `meta.upstream_status: 401` and `meta.upstream_service` for context

### Don't

- `rescue Faraday::UnauthorizedError => e` then always raise 401 — blind pass-through
- Omit `meta.auth_type` — monitoring can't distinguish failure modes

## Anti-Patterns

### Blind Pass-Through

```ruby
rescue Faraday::UnauthorizedError => e
  # BAD: Always returns 401, regardless of whose credentials failed
  raise Common::Exceptions::Unauthorized.new(
    detail: "Upstream authentication failed",
    cause: e
  )
  # If OUR service account is misconfigured, we blame the CLIENT!
  # Missing meta.auth_type — can't tell whose credentials failed
end
```

**Problem:** Always returns 401 regardless of whose credentials failed. If the service account is misconfigured, the client gets 401, retries with different credentials (won't work), and metrics blame client authentication.

**Corrected:**

```ruby
rescue Faraday::UnauthorizedError => e
  if using_service_account_credentials?
    # Our service account failed — this is OUR problem, return 500
    raise Common::Exceptions::InternalServerError.new(
      code: "UPSTREAM_AUTH_CONFIG_ERROR",
      detail: "Service authentication configuration error",
      meta: {
        upstream_status: 401,
        upstream_service: "mpi",
        auth_type: "service_account"
      },
      cause: e
    )
  else
    # User's token failed — this is THEIR problem, return 401
    raise Common::Exceptions::Unauthorized.new(
      detail: "User authentication failed. Please re-authenticate.",
      meta: {
        upstream_status: 401,
        upstream_service: "mpi",
        auth_type: "user_token"
      },
      cause: e
    )
  end
end
```

## Reference

### Token Ownership Decision

| Whose Credentials? | Status | Who Fixes? | Auto-Retry? |
|--------------------|--------|------------|-------------|
| User's OAuth token expired | **401** | Client (refresh token) | Yes |
| Our service account invalid | **500** | Our DevOps team | No (config change) |
| Our API key rotated but not updated | **500** | Our team | No (config change) |
| User provides wrong password | **401** | User | No |
| API key not in request | **401** | Client developer | No |

### Real-World Scenarios

| Scenario | Status | Reasoning |
|----------|--------|-----------|
| Mobile app OAuth token expired (30min TTL) | **401** | User can refresh token automatically |
| vets-api MPI service account misconfigured | **500** | Our credentials failed, not user's |
| vets-api EVSS API key rotated but config not updated | **500** | Our API key wrong, config error |
| Veteran provides wrong password at login | **401** | User's credentials incorrect |

## References

- [RFC 7235 Section 3.1](https://tools.ietf.org/html/rfc7235#section-3.1)
- Related: [Handle 403 Authorization Errors](07-handle-403-permission-vs-existence.md)
- Related: [Match Status Codes to the Source](05-classify-errors-honestly.md)
