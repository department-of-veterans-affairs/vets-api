---
id: dont-leak-pii
title: Don't leak PII, PHI, or secrets in error messages or logs
severity: CRITICAL
---

<!--
<agent_play>

  <context>
    When code logs OAuth tokens to Datadog, anyone with log access gains
    permanent API credentials. Logging medical records—diagnoses,
    medications, and treatments—constitutes a HIPAA PHI violation with
    no encryption or access control. SSNs, dates of birth, and addresses
    appearing in logs can be found with a simple grep, violating minimum
    necessary access requirements. A copy-paste pattern across multiple
    API clients turns a single logging mistake into systemic data
    exposure.
  </context>

  <applies_to>
    <glob>app/controllers/**/*.rb</glob>
    <glob>lib/**/*.rb</glob>
    <glob>modules/*/lib/**/*.rb</glob>
    <glob>app/sidekiq/**/*.rb</glob>
    <glob>modules/*/app/services/**/*.rb</glob>
  </applies_to>

  <related_plays>
    <play id="prefer-structured-logs" relationship="complementary" />
    <play id="handle-403-permission" relationship="complementary" />
  </related_plays>

  <rules>
    <rule enforcement="must_not">
      Never include PII (names, emails, SSNs), PHI (medical info),
      or secrets (API keys, tokens) in error messages or logs.
    </rule>
    <rule enforcement="must">
      Use safe identifiers (UUIDs, internal IDs, case IDs) for
      debugging context in error messages.
    </rule>
    <rule enforcement="must">
      Scrub sensitive data from stack traces and exception messages
      before they reach logging infrastructure.
    </rule>
    <rule enforcement="must">
      Use allowlists for meta fields in structured logs -- never
      blindly include user data or response bodies.
    </rule>
    <rule enforcement="should">
      Apply DataScrubber for automatic PII/PHI redaction on any log
      payload that could contain user data.
    </rule>
    <rule enforcement="verify">
      Search logs for sample SSN/email -- nothing found
    </rule>
    <rule enforcement="verify">
      Code review error handlers for response body logging
    </rule>
    <rule enforcement="verify">
      No `resp.body`, `params`, or `user.to_json` in raise/log
      statements
    </rule>
  </rules>

  <investigate_before_answering>
    <step>Read the full method to identify what data the response body contains. Determine if it is OAuth credentials, medical records (PHI), PII (SSN, DOB), or other sensitive data.</step>
    <step>Identify all raise and log statements in the method that interpolate response bodies. Check for double-logging patterns (HTTP body + nested body).</step>
    <step>Determine what safe identifiers are available in scope (case_id, uuid, request_id, status code) that can replace the response body for debugging.</step>
    <step>Check if this pattern is copy-pasted across sibling API client files in the same module. Search for the same raise pattern in related files.</step>
    <step>Verify whether a typed exception class already exists for this API client, or whether one needs to be created.</step>
  </investigate_before_answering>

  <severity_assessment>
    <critical>response body containing OAuth tokens, API keys, or
credentials is logged or included in raise messages</critical>
    <critical>response body containing PHI (medical records, diagnoses,
treatments) is logged or included in raise messages</critical>
    <critical>PII (SSN, DOB, address) is included in error messages or log
meta fields</critical>
    <high>raw params hash is passed into log meta fields without
allowlisting</high>
    <high>the same leakage pattern is copy-pasted across multiple API
client files</high>
    <medium>response body logged for internal-only API with no user data</medium>
  </severity_assessment>

  <pr_comment_template>
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

    [Play: Don't leak PII, PHI, or secrets](01-dont-leak-pii-phi-secrets.md)
  </pr_comment_template>

</agent_play>
-->

### Do

- Use safe identifiers (UUIDs, internal IDs, case IDs) for debugging context in error messages:
  ```ruby
  raise PegaApiError, "CHAMPVA report failed: HTTP #{resp.status}, case_id: #{case_id}"
  ```
- Scrub sensitive data from stack traces and exception messages before they reach logging infrastructure
- Use allowlists for meta fields in structured logs -- never blindly include user data or response bodies:
  ```ruby
  meta: { case_id: case_id, status: resp.status }
  ```
- Apply DataScrubber for automatic PII/PHI redaction on any log payload that could contain user data

### Don't

- Include PII (names, emails, SSNs), PHI (medical info), or secrets (API keys, tokens) in error messages or logs
- Log `resp.body` or `response.body` in raise/log statements:
  ```ruby
  # BAD -- logs entire response body containing credentials or PHI
  raise "response code: #{resp.status}, response body: #{resp.body}"
  ```
- Pass raw params hash into log metadata fields:
  ```ruby
  # BAD -- params can contain SSNs, DOBs, medical data
  meta: { user_data: params }
  ```

## Anti-Patterns

#### Anti-Pattern #1: Logging entire OAuth token response

##### Anti-Pattern

```ruby
def get_token(auth_code)
  resp = connection.post(config.base_path) do |req|
    req.body = "client_id=#{Settings.dhp.fitbit.client_id}&code=#{auth_code}..."
  end

  raise "response code: #{resp.status}, response body: #{resp.body}" unless resp.status == 200
  # Logs entire OAuth token response body containing access_token, refresh_token, user profile

  JSON.parse(resp.body, symbolize_names: true)
end
```

##### Golden Pattern

```ruby
def get_token(auth_code)
  resp = connection.post(config.base_path) do |req|
    req.body = "client_id=#{Settings.dhp.fitbit.client_id}&code=#{auth_code}..."
  end

  unless resp.status == 200
    raise TokenExchangeError, "Token exchange failed with status #{resp.status}"
    # Logs only status code, not response body with credentials
  end

  JSON.parse(resp.body, symbolize_names: true)
end
```

#### Anti-Pattern #2: Logging CHAMPVA medical report response

##### Anti-Pattern

```ruby
def get_report(date_start, date_end, case_id = '', uuid = '')
  resp = connection.post(config.base_path) do |req|
    req.headers = headers(date_start, date_end, case_id, uuid)
  end

  raise "response code: #{resp.status}, response body: #{resp.body}" unless resp.status == 200
  # Logs entire CHAMPVA medical report response (PHI: diagnoses, treatments, prescriptions)
  # This exact pattern appears in 5 API clients, exposing PHI/PII/credentials systemically

  response = JSON.parse(resp.body, symbolize_names: false)
  unless response['statusCode'] == 200
    raise "alternate response code: #{response['statusCode']}, response body: #{response['body']}"
    # Logs response body AGAIN, doubling PHI exposure
  end

  JSON.parse(response['body'])
end
```

##### Golden Pattern

```ruby
def get_report(date_start, date_end, case_id = '', uuid = '')
  resp = connection.post(config.base_path) do |req|
    req.headers = headers(date_start, date_end, case_id, uuid)
  end

  unless resp.status == 200
    raise PegaApiError, "CHAMPVA report failed: HTTP #{resp.status}, case_id: #{case_id}"
    # Logs only status code + safe case_id, not PHI-laden response
  end

  response = JSON.parse(resp.body, symbolize_names: false)
  unless response['statusCode'] == 200
    raise PegaApiError, "CHAMPVA report internal error: status #{response['statusCode']}, case_id: #{case_id}"
    # Logs only status code, not nested response body with medical records
  end

  JSON.parse(response['body'])
end
```
