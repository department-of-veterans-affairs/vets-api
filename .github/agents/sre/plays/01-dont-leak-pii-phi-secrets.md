# Play 01: Don't Leak PII, PHI, or Secrets in Error Messages or Logs

## Context
When code logs OAuth tokens to Datadog, anyone with log access gains permanent API credentials. Logging medical records -- diagnoses, medications, and treatments -- constitutes a HIPAA PHI violation with no encryption or access control. SSNs, dates of birth, and addresses appearing in logs can be found with a simple grep, violating minimum necessary access requirements. A copy-paste pattern across multiple API clients turns a single logging mistake into systemic data exposure.

## Applies To
- `app/controllers/**/*.rb`
- `lib/**/*.rb`
- `modules/*/lib/**/*.rb`
- `app/sidekiq/**/*.rb`
- `modules/*/app/services/**/*.rb`

## Investigation Steps
1. Read the full method to identify what data the response body contains. Determine if it is OAuth credentials, medical records (PHI), PII (SSN, DOB), or other sensitive data.
2. Identify all raise and log statements in the method that interpolate response bodies. Check for double-logging patterns (HTTP body + nested body).
3. Determine what safe identifiers are available in scope (case_id, uuid, request_id, status code) that can replace the response body for debugging.
4. Check if this pattern is copy-pasted across sibling API client files in the same module. Search for the same raise pattern in related files.
5. Verify whether a typed exception class already exists for this API client, or whether one needs to be created.

## Severity Assessment
- **CRITICAL**: Response body containing OAuth tokens, API keys, or credentials is logged or included in raise messages
- **CRITICAL**: Response body containing PHI (medical records, diagnoses, treatments) is logged or included in raise messages
- **CRITICAL**: PII (SSN, DOB, address) is included in error messages or log meta fields
- **HIGH**: Raw params hash is passed into log meta fields without allowlisting
- **HIGH**: The same leakage pattern is copy-pasted across multiple API client files
- **MEDIUM**: Response body logged for internal-only API with no user data

## Golden Patterns

### Do
Use safe identifiers (UUIDs, internal IDs, case IDs) for debugging context in error messages:
```ruby
raise PegaApiError, "CHAMPVA report failed: HTTP #{resp.status}, case_id: #{case_id}"
```

Use allowlists for meta fields in structured logs -- never blindly include user data or response bodies:
```ruby
meta: { case_id: case_id, status: resp.status }
```

Scrub sensitive data from stack traces and exception messages before they reach logging infrastructure. Apply DataScrubber for automatic PII/PHI redaction on any log payload that could contain user data.

### Don't
Never include PII (names, emails, SSNs), PHI (medical info), or secrets (API keys, tokens) in error messages or logs.

Never log `resp.body` or `response.body` in raise/log statements:
```ruby
# BAD -- logs entire response body containing credentials or PHI
raise "response code: #{resp.status}, response body: #{resp.body}"
```

Never pass raw params hash into log metadata fields:
```ruby
# BAD -- params can contain SSNs, DOBs, medical data
meta: { user_data: params }
```

## Anti-Patterns

### Logging entire OAuth token response
**Anti-pattern:**
```ruby
def get_token(auth_code)
  resp = connection.post(config.base_path) do |req|
    req.body = "client_id=#{Settings.dhp.fitbit.client_id}&code=#{auth_code}..."
  end

  raise "response code: #{resp.status}, response body: #{resp.body}" unless resp.status == 200

  JSON.parse(resp.body, symbolize_names: true)
end
```
**Problem:** Logs entire OAuth token response body containing access_token, refresh_token, and user profile data (PHI under HIPAA). Leaked refresh tokens grant permanent access to user accounts. Log exfiltration exposes both credentials and health data.

**Corrected:**
```ruby
def get_token(auth_code)
  resp = connection.post(config.base_path) do |req|
    req.body = "client_id=#{Settings.dhp.fitbit.client_id}&code=#{auth_code}..."
  end

  unless resp.status == 200
    raise TokenExchangeError, "Token exchange failed with status #{resp.status}"
  end

  JSON.parse(resp.body, symbolize_names: true)
end
```

### Logging CHAMPVA medical report response
**Anti-pattern:**
```ruby
def get_report(date_start, date_end, case_id = '', uuid = '')
  resp = connection.post(config.base_path) do |req|
    req.headers = headers(date_start, date_end, case_id, uuid)
  end

  raise "response code: #{resp.status}, response body: #{resp.body}" unless resp.status == 200

  response = JSON.parse(resp.body, symbolize_names: false)
  unless response['statusCode'] == 200
    raise "alternate response code: #{response['statusCode']}, response body: #{response['body']}"
  end

  JSON.parse(response['body'])
end
```
**Problem:** Logs entire CHAMPVA medical report response containing PHI (diagnoses, treatments, prescriptions). Double-logs: both the HTTP response body AND the nested `response['body']`. This exact pattern appears in 5 API clients, creating systemic PHI/PII/credential exposure. Centralized logs (Datadog) retain PHI indefinitely in searchable format, constituting a HIPAA violation.

**Corrected:**
```ruby
def get_report(date_start, date_end, case_id = '', uuid = '')
  resp = connection.post(config.base_path) do |req|
    req.headers = headers(date_start, date_end, case_id, uuid)
  end

  unless resp.status == 200
    raise PegaApiError, "CHAMPVA report failed: HTTP #{resp.status}, case_id: #{case_id}"
  end

  response = JSON.parse(resp.body, symbolize_names: false)
  unless response['statusCode'] == 200
    raise PegaApiError, "CHAMPVA report internal error: status #{response['statusCode']}, case_id: #{case_id}"
  end

  JSON.parse(response['body'])
end
```

## Finding Template
**Don't leak PII, PHI, or secrets in error messages or logs** | `CRITICAL`

`{{file_path}}:{{line_number}}` -- `raise` interpolates `resp.body` which
contains {{sensitive_data_type}}. This data is persisted in Datadog/Sentry
logs where it is searchable and accessible to engineers.

**Why this matters:** {{specific_consequence}} (e.g., OAuth tokens in logs
grant permanent API access; medical records in logs violate HIPAA).

**Suggested fix:**
```ruby
{{suggested_code}}
```

**Verify:**
- [ ] No `resp.body` or `response.body` in raise/log statements
- [ ] Error messages contain only safe identifiers (status code, case_id, uuid)
- [ ] Sibling API client files checked for same pattern
- [ ] Meta fields use allowlisted safe fields only

[Play: Don't leak PII, PHI, or secrets](plays/dont-leak-pii-phi-secrets.md)

## Verify Commands
- `grep -On 'raise\s+".*resp\.body|raise\s+".*response.*body' {{file_path}}` -- No response body in raise statements
- `grep -On 'meta:.*params' {{file_path}}` -- No raw params in meta fields
- `grep -On 'logger\.\w+.*\.body' {{file_path}}` -- No logger calls with response body
- `bundle exec rspec {{spec_path}}` -- Run specs for changed file
- `bundle exec rubocop {{file_path}}` -- RuboCop passes for changed file

## Related Plays
- prefer-structured-logs (complementary)
- handle-403-permission (complementary)
