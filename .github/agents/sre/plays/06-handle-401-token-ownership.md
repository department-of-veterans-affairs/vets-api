# Play 06: Handle 401 Authentication Errors (Token Ownership Matters!)

## Context
When our service account credentials fail, returning 401 makes the client think they failed, so metrics blame the client and the wrong team gets paged. The client retries with a refresh token, but that will never work because our configuration is broken, not theirs. Dashboards show "authentication errors" and the team investigates user auth, when the actual problem is that our MPI credentials have expired. A 401 means "client, fix your credentials" while a 500 means "we need to fix this," so getting the code wrong misdirects the entire incident response.

## Applies To
- `app/controllers/**/*.rb`
- `modules/*/app/controllers/**/*.rb`
- `lib/**/*.rb`
- `modules/*/lib/**/*.rb`

## Investigation Steps
1. Read the full method containing the rescue block to understand what upstream service is being called and what credentials are used for the request.
2. Determine whether the upstream call uses user-provided credentials (OAuth token from session) or service account credentials (configured API keys, service accounts from environment variables or credential stores).
3. Check if the service client configuration includes service account credentials (look for API key settings, service account configs, or client certificate configurations in the service wrapper).
4. Identify whether the module already has helper methods for checking credential type (e.g., `using_service_account_credentials?`, `service_auth?`).
5. Check what meta fields are already included on the raised exception to determine what upstream context is preserved. Do not suggest fixes without understanding which credentials the upstream call uses. The correct status code depends entirely on whose credentials failed.

## Severity Assessment
- **CRITICAL**: Upstream 401 from a service using service account credentials is passed through as 401 to the client
- **CRITICAL**: `rescue Faraday::UnauthorizedError` raises Unauthorized without checking credential type
- **HIGH**: 401 exception raised without meta.auth_type -- cannot distinguish user token from service account failures
- **HIGH**: Service account failure returns 401 and monitoring attributes it to client authentication
- **MEDIUM**: 401 exception missing meta.upstream_service or meta.upstream_status context

## Golden Patterns

### Do
Check whose credentials failed before choosing status code:
```ruby
rescue Faraday::UnauthorizedError => e
  if using_service_account_credentials?
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

### Don't
Never blindly pass through upstream 401 as 401 to clients:
```ruby
# BAD
rescue Faraday::UnauthorizedError => e
  raise Common::Exceptions::Unauthorized.new(
    detail: "Upstream authentication failed",
    cause: e
  )
  # If OUR service account is misconfigured, we blame the CLIENT!
end
```

Never omit `meta.auth_type` -- monitoring cannot distinguish failure modes.

## Anti-Patterns

### Blind Pass-Through
**Anti-pattern:**
```ruby
rescue Faraday::UnauthorizedError => e
  raise Common::Exceptions::Unauthorized.new(
    detail: "Upstream authentication failed",
    cause: e
  )
  # If OUR service account is misconfigured, we blame the CLIENT!
  # Missing meta.auth_type -- can't tell whose credentials failed
end
```
**Problem:** Always returns 401 regardless of whose credentials failed. If the service account is misconfigured, the client gets 401, retries with different credentials (will not work), and metrics blame client authentication. The wrong team gets paged and the actual configuration problem goes undetected.

**Corrected:**
```ruby
rescue Faraday::UnauthorizedError => e
  if using_service_account_credentials?
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

## Finding Template
**Handle 401 Authentication Errors (Token Ownership Matters!)** | `CRITICAL`

`{{file_path}}:{{line_number}}` -- Upstream 401 passed through as 401 without
checking whose credentials failed. If this service uses service account
credentials, the 401 should be remapped to 500 (our config error, not client's
auth failure).

**Why this matters:** When our service account credentials fail upstream and we
return 401, the client thinks THEY need to re-authenticate. They refresh their
token and retry -- it still fails. Metrics blame the client. Wrong team gets
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

## Verify Commands
- `grep -On 'rescue.*UnauthorizedError.*\n.*raise.*Unauthorized' {{file_path}} | grep -v 'auth_type'` -- No blind 401 pass-through without auth_type check
- `grep -On 'raise.*Unauthorized\|raise.*InternalServerError.*AUTH' {{file_path}} | grep -v 'auth_type'` -- All auth exceptions include meta.auth_type
- `bundle exec rspec {{spec_path}}` -- Run specs for changed file
- `bundle exec rubocop {{file_path}}` -- RuboCop passes for changed file

## Related Plays
- handle-403-permission (complementary)
- classify-errors (complementary)
