# Play 13: Send Retry Hints Only When Safe and Useful

## Context
A 429 response without a Retry-After header causes the client to retry immediately, hit the rate limit again, and repeat, creating a thundering herd that degrades the service. When the upstream sends "retry in 60s" but our code catches the 429 and discards the header, the client retries in one second and triggers cascading rate limits. Converting a 429 to a 503 makes the client think the service is down, when it should know "too many requests," leading to the wrong diagnosis and wrong UX.

## Applies To
- `config/initializers/**/*.rb`
- `app/controllers/**/*.rb`
- `modules/*/app/controllers/**/*.rb`
- `lib/**/*.rb`

## Investigation Steps
1. Read the full response construction or rescue block to understand what status code is being returned (429, 503, or other).
2. Determine whether upstream Retry-After timing is available -- check if the caught exception provides `response.headers['Retry-After']`.
3. Check whether the code is a rate-limiting middleware (like Rack::Attack) that controls the rate limit period, or a service layer that proxies upstream 429 responses.
4. Verify whether the codebase has a `Common::Exceptions::TooManyRequests` class. If converting from 503, the correct exception class must exist.
5. Check if callers or middleware add Retry-After downstream -- the header may be set at a different layer. Do not suggest fixes based on the rescue block alone.

## Severity Assessment
- **CRITICAL:** 429 response from rate limiter missing Retry-After -- thundering herd risk for all clients
- **HIGH:** Upstream Retry-After header discarded when catching 429 -- cascading rate limits
- **HIGH:** 429 converted to 503 -- loses rate limit semantic meaning, wrong client behavior
- **MEDIUM:** Retry-After value calculated incorrectly (negative or zero) but header is present

## Golden Patterns

### Do
Include `Retry-After` header with 429 responses:
```ruby
headers['Retry-After'] = (reset_time - now).to_i.to_s
[429, headers, ['Rate limit exceeded']]
```

Propagate upstream `Retry-After` timing through exception metadata:
```ruby
retry_after = error.response.headers['Retry-After']
raise_backend_exception(
  error_code_name(error.status), self.class, error,
  meta: { retry_after: retry_after }.compact
)
```

Preserve 429 status code semantic meaning:
```ruby
raise Common::Exceptions::TooManyRequests.new(
  detail: 'Rate limit exceeded',
  meta: { retry_after: retry_after }
)
```

### Don't
Never send `Retry-After` for permanent failures (404, 410, 403) -- retrying will not help:
```ruby
# BAD: 404 is permanent; Retry-After misleads the client
render json: { errors: [...] }, status: :not_found,
       headers: { 'Retry-After' => '60' }
```

Never convert 429 to 503 -- this loses the "rate limit" semantic meaning:
```ruby
# BAD: client thinks service is down, not that they hit a rate limit
rescue service::TooManyRequestsError
  raise Common::Exceptions::ServiceUnavailable, detail: 'Temporary issue'
end
```

Never send `Retry-After` for bugs/crashes (500 without upstream guidance):
```ruby
# BAD: a code bug won't fix itself after 60 seconds
render json: { errors: [...] }, status: :internal_server_error,
       headers: { 'Retry-After' => '60' }
```

## Anti-Patterns

### Rack::Attack Configuration
**Anti-pattern:**
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
**Problem:** Clients receive `X-RateLimit-Reset` (non-standard, GitHub-specific format). HTTP client libraries do not understand custom headers for automatic retry backoff. Clients must manually parse the timestamp. Mobile/web apps retry immediately with no backoff guidance.

**Corrected:**
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

### SearchGSA Service
**Anti-pattern:**
```ruby
def handle_429!(error)
  return unless error.status == 429

  StatsD.increment("#{SearchGsa::Service::STATSD_KEY_PREFIX}.exceptions", tags: ['exception:429'])
  raise_backend_exception(error_code_name(error.status), self.class, error)
  # Doesn't extract or propagate error.response.headers['Retry-After']
end
```
**Problem:** Upstream GSA API provides `Retry-After` guidance but the service catches 429 and discards retry timing information. Clients retry immediately without backoff, triggering cascading 429s.

**Corrected:**
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
end
```

### Accredited Representative Portal
**Anti-pattern:**
```ruby
rescue service::TooManyRequestsError
  span.set_tag('error.specific_reason', 'too_many_requests')
  raise Common::Exceptions::ServiceUnavailable, detail: 'Temporary system issue'
  # Converts 429 -> 503 (loses "rate limit" semantic meaning)
  # No Retry-After header or meta with timing
end
```
**Problem:** Upstream returns 429 (rate limit) with specific retry timing. Controller converts to 503 (generic service unavailable). Client does not know if they should retry in 1 second, 1 minute, or 1 hour. Loses semantic meaning: 503 suggests "service down" not "you're making too many requests."

**Corrected:**
```ruby
rescue service::TooManyRequestsError => e
  span.set_tag('error.specific_reason', 'too_many_requests')
  retry_after = e.response&.headers&.[]('Retry-After') || 60

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

## Finding Template
**Send Retry Hints only when safe and useful** | `HIGH`

`{{file_path}}:{{line_number}}` -- {{one_line_violation_description}}

**Why this matters:** Without Retry-After, clients retry immediately after
receiving 429. This creates a thundering herd that degrades the service for
all users. Standard HTTP clients recognize Retry-After and implement automatic
backoff -- but only if the header is present.

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

## Verify Commands
```bash
# No 429 response without Retry-After in changed file
grep -On '\[429,.*headers' {{file_path}} | grep -v 'Retry-After' && exit 1 || exit 0

# No 429-to-503 conversion in changed file
grep -On 'ServiceUnavailable.*TooManyRequests|TooManyRequests.*ServiceUnavailable' {{file_path}} && exit 1 || exit 0

# Run specs for changed file
bundle exec rspec {{spec_path}}

# RuboCop passes for changed file
bundle exec rubocop {{file_path}}
```

## Related Plays
- Play: Respect Retry Headers (complementary)
- Play: Standardized Error Responses (complementary)
