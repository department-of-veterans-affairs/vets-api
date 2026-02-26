---
id: send-retry-hints
title: Send Retry Hints only when safe and useful
severity: HIGH
---

<!--
<agent_play>

  <context>
    A 429 response without a Retry-After header causes the client to
    retry immediately, hit the rate limit again, and repeat, creating a
    thundering herd that degrades the service. When the upstream sends
    "retry in 60s" but our code catches the 429 and discards the header,
    the client retries in one second and triggers cascading rate limits.
    Converting a 429 to a 503 makes the client think the service is
    down, when it should know "too many requests," leading to the wrong
    diagnosis and wrong UX. HTTP clients can auto-retry using the Retry-
    After header, but a missing header forces manual backoff logic that
    means more code and more bugs.
  </context>

  <applies_to>
    <glob>config/initializers/**/*.rb</glob>
    <glob>app/controllers/**/*.rb</glob>
    <glob>modules/*/app/controllers/**/*.rb</glob>
    <glob>lib/**/*.rb</glob>
  </applies_to>

  <related_plays>
    <play id="respect-retry-headers" relationship="complementary" />
    <play id="standardized-error-responses" relationship="complementary" />
  </related_plays>

  <rules>
    <rule enforcement="must">
      Include Retry-After header when upstream provides it or when
      you enforce rate limits.
    </rule>
    <rule enforcement="must">
      Always include Retry-After with 429 Too Many Requests
      responses.
    </rule>
    <rule enforcement="must_not">
      Never send Retry-After for permanent failures (404, 410, 403)
      — retrying will not help.
    </rule>
    <rule enforcement="must_not">
      Never send Retry-After for bugs/crashes (500 without upstream
      guidance).
    </rule>
    <rule enforcement="must_not">
      Never convert 429 to 503 — preserve the "rate limit" semantic
      meaning.
    </rule>
    <rule enforcement="should">
      Propagate upstream Retry-After timing through exception
      metadata to the client.
    </rule>
    <rule enforcement="verify">
      All 429 responses include Retry-After header
    </rule>
    <rule enforcement="verify">
      Upstream retry timing propagates to clients
    </rule>
    <rule enforcement="verify">
      Clients respect retry guidance (no immediate retry storms)
    </rule>
    <rule enforcement="verify">
      Frontend shows "retry in X seconds" message to users
    </rule>
  </rules>

  <investigate_before_answering>
    <step>Read the full response construction or rescue block to understand what status code is being returned (429, 503, or other).</step>
    <step>Determine whether upstream Retry-After timing is available — check if the caught exception provides `response.headers['Retry-After']`.</step>
    <step>Check whether the code is a rate-limiting middleware (like Rack::Attack) that controls the rate limit period, or a service layer that proxies upstream 429 responses.</step>
    <step>Verify whether the codebase has a `Common::Exceptions::TooManyRequests` class. If converting from 503, the correct exception class must exist.</step>
    <step>Check if callers or middleware add Retry-After downstream — the header may be set at a different layer (e.g., middleware adds it to all 429s). Do not suggest fixes based on the rescue block alone. The correct remediation depends on whether retry timing comes from the rate limiter configuration or from upstream response headers.</step>
  </investigate_before_answering>

  <severity_assessment>
    <critical>429 response from rate limiter missing Retry-After —
thundering herd risk for all clients</critical>
    <high>upstream Retry-After header discarded when catching 429 —
cascading rate limits</high>
    <high>429 converted to 503 — loses rate limit semantic meaning,
wrong client behavior</high>
    <medium>Retry-After value calculated incorrectly (negative or zero)
but header is present</medium>
  </severity_assessment>

  <pr_comment_template>
    **Send Retry Hints only when safe and useful** | `HIGH`

    `{{file_path}}:{{line_number}}` — {{one_line_violation_description}}

    **Why this matters:** Without Retry-After, clients retry immediately after
    receiving 429. This creates a thundering herd that degrades the service for
    all users. Standard HTTP clients recognize Retry-After and implement automatic
    backoff — but only if the header is present.

    **Suggested fix:**
    ```ruby
    {{suggested_code}}
    ```

    **Verify:**
    - [ ] 429 response includes Retry-After header
    - [ ] Upstream Retry-After propagated through exception metadata
    - [ ] No 429-to-503 conversion (preserves rate limit semantics)
    - [ ] Retry-After value is positive integer in seconds

    **References:**
    - [RFC 6585 Section 4](https://tools.ietf.org/html/rfc6585#section-4)
    - [RFC 7231 Retry-After](https://tools.ietf.org/html/rfc7231#section-7.1.3)

    [Play: Send Retry Hints](13-send-retry-hints-to-clients.md)
  </pr_comment_template>

</agent_play>
-->

### Do

- Include `Retry-After` header with 429 responses:
  ```ruby
  headers['Retry-After'] = (reset_time - now).to_i.to_s
  [429, headers, ['Rate limit exceeded']]
  ```
- Propagate upstream `Retry-After` timing through exception metadata:
  ```ruby
  retry_after = error.response.headers['Retry-After']
  raise_backend_exception(
    error_code_name(error.status), self.class, error,
    meta: { retry_after: retry_after }.compact
  )
  ```
- Preserve 429 status code semantic meaning:
  ```ruby
  raise Common::Exceptions::TooManyRequests.new(
    detail: 'Rate limit exceeded',
    meta: { retry_after: retry_after }
  )
  ```

### Don't

- Send `Retry-After` for permanent failures (404, 410, 403) -- retrying will not help:
  ```ruby
  # BAD: 404 is permanent; Retry-After misleads the client
  render json: { errors: [...] }, status: :not_found,
         headers: { 'Retry-After' => '60' }
  ```
- Convert 429 to 503 -- this loses the "rate limit" semantic meaning:
  ```ruby
  # BAD: client thinks service is down, not that they hit a rate limit
  rescue service::TooManyRequestsError
    raise Common::Exceptions::ServiceUnavailable, detail: 'Temporary issue'
  end
  ```
- Send `Retry-After` for bugs/crashes (500 without upstream guidance):
  ```ruby
  # BAD: a code bug won't fix itself after 60 seconds
  render json: { errors: [...] }, status: :internal_server_error,
         headers: { 'Retry-After' => '60' }
  ```

## Anti-Patterns

#### Rack::Attack Configuration

##### Anti-Pattern

```ruby
Rack::Attack.throttled_responder = lambda do |request|
  rate_limit = request.env['rack.attack.match_data']
  now = Time.zone.now
  headers = {
    'X-RateLimit-Limit' => rate_limit[:limit].to_s,
    'X-RateLimit-Remaining' => '0',
    'X-RateLimit-Reset' => (now + (rate_limit[:period] - (now.to_i % rate_limit[:period]))).to_i
    # Missing standard 'Retry-After' header
  }

  [429, headers, ['throttled']]
end
```

##### Golden Pattern

```ruby
Rack::Attack.throttled_responder = lambda do |request|
  rate_limit = request.env['rack.attack.match_data']
  now = Time.zone.now
  reset_time = now + (rate_limit[:period] - (now.to_i % rate_limit[:period]))

  headers = {
    'X-RateLimit-Limit' => rate_limit[:limit].to_s,
    'X-RateLimit-Remaining' => '0',
    'X-RateLimit-Reset' => reset_time.to_i.to_s,
    'Retry-After' => (reset_time - now).to_i.to_s  # RFC 6585 standard
  }

  [429, headers, ['Rate limit exceeded']]
end
```

#### SearchGSA Service

##### Anti-Pattern

```ruby
def handle_429!(error)
  return unless error.status == 429

  StatsD.increment("#{SearchGsa::Service::STATSD_KEY_PREFIX}.exceptions", tags: ['exception:429'])
  raise_backend_exception(error_code_name(error.status), self.class, error)
  # Doesn't extract or propagate error.response.headers['Retry-After']
end
```

##### Golden Pattern

```ruby
def handle_429!(error)
  return unless error.status == 429

  retry_after = error.response.headers['Retry-After']
  StatsD.increment("#{STATSD_KEY_PREFIX}.exceptions", tags: ['exception:429'])

  raise_backend_exception(
    error_code_name(error.status),
    self.class,
    error,
    meta: { retry_after: retry_after, upstream_service: 'gsa_search' }.compact
  )
  # Propagates upstream retry guidance to client
end
```

#### Accredited Representative Portal

##### Anti-Pattern

```ruby
rescue service::TooManyRequestsError
  span.set_tag('error.specific_reason', 'too_many_requests')
  raise Common::Exceptions::ServiceUnavailable, detail: 'Temporary system issue'
  # Converts 429→503 (loses "rate limit" semantic meaning)
  # No Retry-After header or meta with timing
end
```

##### Golden Pattern

```ruby
rescue service::TooManyRequestsError => e
  span.set_tag('error.specific_reason', 'too_many_requests')
  retry_after = e.response&.headers&.[]('Retry-After') || 60  # Default to 60s

  raise Common::Exceptions::TooManyRequests.new(
    detail: 'Rate limit exceeded',
    meta: {
      retry_after: retry_after,
      upstream_service: 'form_upload_service'
    },
    cause: e
  )
  # Preserves 429 status and includes retry guidance
end
```
