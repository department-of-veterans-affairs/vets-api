---
id: handle-401-token-ownership
title: Handle 401 Authentication Errors (Token Ownership Matters!)
severity: CRITICAL
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

    [Play: Handle 401 Authentication Errors](06-handle-401-token-ownership.md)
  </pr_comment_template>

</agent_play>
-->

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
