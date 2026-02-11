---
id: send-retry-hints
title: Send Retry Hints only when safe and useful
version: 1
severity: HIGH
category: retry-resilience
tags:
- retry-after
- 429
- rate-limiting
- thundering-herd
- rack-attack
language: ruby
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

  <retrieval_triggers>
    <trigger>429 response missing Retry-After header</trigger>
    <trigger>upstream Retry-After header discarded when catching 429</trigger>
    <trigger>rate limit 429 converted to 503 service unavailable</trigger>
    <trigger>thundering herd from missing retry guidance</trigger>
    <trigger>client retries immediately without backoff</trigger>
  </retrieval_triggers>

  <detection>
    <pattern name="429_response_missing_retry_after" confidence="high">
      <signature>\[429,.*headers</signature>
      <description>
        A 429 response being constructed with a headers hash. Check
        that the headers hash includes a 'Retry-After' key. If it does
        not, clients have no standard guidance on when to retry and
        will hammer the endpoint immediately.
      </description>
      <example>[429, headers, ['throttled']]</example>
      <example>[429, { 'X-RateLimit-Limit' =&gt; ... }, [body]]</example>
    </pattern>
    <pattern name="429_converted_to_503" confidence="high">
      <signature>raise.*ServiceUnavailable.*TooManyRequests</signature>
      <description>
        A rescue block that catches a TooManyRequests (429) error and
        re-raises it as ServiceUnavailable (503). This loses the "rate
        limit" semantic meaning and makes clients believe the service
        is down rather than telling them they are making too many
        requests. Retry-After timing is also discarded.
      </description>
      <example>rescue service::TooManyRequestsError; raise Common::Exceptions::ServiceUnavailable</example>
      <example>rescue TooManyRequests =&gt; e; raise ServiceUnavailable, detail: 'Temporary issue'</example>
    </pattern>
    <pattern name="handle_429_without_retry_after" confidence="medium">
      <signature>handle_429</signature>
      <description>
        A method named handle_429 or similar that processes 429
        responses. Medium confidence because the method may or may not
        extract the Retry-After header. Agent should read surrounding
        code to check whether response headers are propagated to the
        caller or discarded.
      </description>
      <example>def handle_429!(error)</example>
      <example>def handle_429(response)</example>
    </pattern>
    <heuristic>
      A Rack::Attack throttled_responder lambda that constructs a
      429 response with X-RateLimit-* headers but no Retry-After
      header. The X-RateLimit headers are non-standard (GitHub-
      specific) and not recognized by HTTP client libraries for
      automatic retry backoff.
    </heuristic>
    <heuristic>
      A rescue block that catches a 429 error from an upstream
      service, increments a StatsD counter, and re-raises a backend
      exception without extracting `error.response.headers['Retry-
      After']`. The upstream retry timing is available but
      discarded.
    </heuristic>
    <heuristic>
      A controller rescue block that catches TooManyRequestsError
      and raises ServiceUnavailable with a generic detail message.
      The 429-to-503 conversion is a strong signal that retry
      semantics are being lost.
    </heuristic>
    <false_positive>
      A 429 response that already includes a Retry-After header
      alongside X-RateLimit-* headers. The presence of both is
      correct and not a violation. Only flag when Retry-After is
      missing.
    </false_positive>
    <false_positive>
      A handle_429 method that extracts Retry-After from response
      headers and passes it through in exception metadata. Read the
      full method body before flagging — the propagation may happen
      via `meta:` or a custom header.
    </false_positive>
  </detection>

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

  <default_to_action>
    When you detect a missing Retry-After or 429-to-503 conversion
    with high confidence, compose a PR comment that includes: 1.
    The specific violation (missing header, discarded header, or
    status conversion) 2. Why it matters (thundering herd,
    cascading rate limits, wrong client UX) 3. A concrete code
    suggestion from the golden patterns 4. The relevant RFC
    reference (6585 or 7231) 5. A link to this play for full
    context Do not simply flag the violation — provide the fix.
    Include the exact header or exception change needed.
  </default_to_action>

  <verify>
    <command description="No 429 response without Retry-After in changed file">
      grep -On '\[429,.*headers' {{file_path}} | grep -v 'Retry-After' &amp;&amp; exit 1 || exit 0
    </command>
    <command description="No 429-to-503 conversion in changed file">
      grep -On 'ServiceUnavailable.*TooManyRequests|TooManyRequests.*ServiceUnavailable' {{file_path}} &amp;&amp; exit 1 || exit 0
    </command>
    <command description="Run specs for changed file">
      bundle exec rspec {{spec_path}}
    </command>
    <command description="RuboCop passes for changed file">
      bundle exec rubocop {{file_path}}
    </command>
  </verify>

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

    [Play: Send Retry Hints](plays/send-retry-hints-to-clients.md)
  </pr_comment_template>

  <anti_pattern_sources>
    <source name="Rack::Attack Configuration" file="config/initializers/rack_attack.rb:68-79" url="https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/config/initializers/rack_attack.rb#L68-L79" />
    <source name="SearchGSA Service" file="lib/search_gsa/service.rb:113-118" url="https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/lib/search_gsa/service.rb#L113-L118" />
    <source name="Accredited Representative Portal" file="modules/accredited_representative_portal/app/controllers/accredited_representative_portal/v0/representative_form_upload_controller.rb:52-54" url="https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/modules/accredited_representative_portal/app/controllers/accredited_representative_portal/v0/representative_form_upload_controller.rb#L52-L54" />
  </anti_pattern_sources>

</agent_play>
-->

# Send Retry Hints only when safe and useful

Retry-After headers tell clients exactly when to try again. When used correctly on 429 responses, they prevent thundering herds and let HTTP client libraries handle backoff automatically.

> [!CAUTION]
> Missing `Retry-After` on 429 responses causes thundering herds -- clients retry immediately and amplify the overload.

## Why It Matters

A 429 response without a Retry-After header causes your client to retry immediately, hit the rate limit again, and repeat -- creating a thundering herd that degrades the service for everyone. When an upstream service sends "retry in 60s" but your code catches the 429 and discards the header, the client retries in one second and triggers cascading rate limits across multiple services. Converting a 429 to a 503 makes your client think the service is down when it should know "too many requests," leading to the wrong diagnosis and wrong UX. Standard HTTP client libraries can auto-retry using Retry-After, but a missing header forces manual backoff logic that means more code and more bugs.

## Guidance

Include a `Retry-After` header on every 429 response you generate. When proxying upstream 429 responses, extract the upstream `Retry-After` value and propagate it through exception metadata so the client receives the original timing. Never convert 429 to 503 -- preserve the rate-limit semantic so clients and monitoring can distinguish "too many requests" from "service down."

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

### Anti-Patterns from vets-api

#### Rack::Attack Configuration

##### Anti-Pattern

[config/initializers/rack_attack.rb:68-79](https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/config/initializers/rack_attack.rb#L68-L79)

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

##### Impact

Without `Retry-After` header:

- Clients receive `X-RateLimit-Reset` (non-standard, GitHub-specific format)
- HTTP client libraries don't understand custom headers for automatic retry backoff
- Clients must manually parse `X-RateLimit-Reset` timestamp to calculate wait time
- Mobile/web apps retry immediately and hit limit again (no exponential backoff guidance)

With `Retry-After` header:

- Standard HTTP clients (Faraday, axios, fetch) recognize `Retry-After` automatically
- Client libraries implement automatic retry backoff without custom code
- Reduces thundering herd when rate limit resets

---

#### SearchGSA Service

##### Anti-Pattern

[lib/search_gsa/service.rb:113-118](https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/lib/search_gsa/service.rb#L113-L118)

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

##### Impact

Without propagating `Retry-After`:

- Upstream GSA API provides `Retry-After` guidance (e.g., "60 seconds")
- Service catches 429 but discards retry timing information
- Clients retry immediately without backoff
- Triggers cascading 429s across all clients

With propagating `Retry-After`:

- Upstream retry guidance flows through to end clients
- Clients wait the recommended time before retrying
- Reduces load on both vets-api and upstream GSA service

---

#### Accredited Representative Portal

##### Anti-Pattern

[modules/accredited_representative_portal/app/controllers/accredited_representative_portal/v0/representative_form_upload_controller.rb:52-54](https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/modules/accredited_representative_portal/app/controllers/accredited_representative_portal/v0/representative_form_upload_controller.rb#L52-L54)

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

##### Impact

Without preserving 429 and retry timing:

- Upstream returns 429 (rate limit) with specific retry timing
- Controller converts to 503 (generic service unavailable)
- Client doesn't know if they should retry in 1 second, 1 minute, or 1 hour
- Loses semantic meaning: 503 suggests "service down" not "you're making too many requests"
- Clients retry immediately and hit limit again

With preserving 429 and retry timing:

- Client knows it's a rate limit (429), not service outage (503)
- Client respects `Retry-After` guidance
- Frontend can show user-friendly message: "Too many requests. Try again in 60 seconds"
- Reduces unnecessary retries and server load

## References

- [RFC 6585 Section 4](https://tools.ietf.org/html/rfc6585#section-4)
- [RFC 7231 Retry-After](https://tools.ietf.org/html/rfc7231#section-7.1.3)
