---
id: dont-leak-pii
title: Don't leak PII, PHI, or secrets in error messages or logs
version: 1
severity: CRITICAL
category: security
tags:
- pii
- phi
- secrets
- hipaa
- data-leakage
- logging
language: ruby
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

  <retrieval_triggers>
    <trigger>response body logged containing OAuth tokens or credentials</trigger>
    <trigger>PHI medical records in error messages or logs</trigger>
    <trigger>PII like SSN or DOB in exception messages</trigger>
    <trigger>API response body in raise string interpolation</trigger>
    <trigger>secrets or tokens leaked to Datadog logs</trigger>
  </retrieval_triggers>

  <detection>
    <pattern name="response_body_in_raise" confidence="high">
      <signature>raise\s+".*resp\.body</signature>
      <description>
        String interpolation of `resp.body` inside a raise statement.
        This logs the entire HTTP response body into the exception
        message, which propagates to APM, Sentry, and Datadog.
        Response bodies from OAuth endpoints contain access tokens and
        refresh tokens. Response bodies from medical APIs contain PHI
        (diagnoses, treatments, prescriptions).
      </description>
      <example>raise "response code: #{resp.status}, response body: #{resp.body}"</example>
      <example>raise "failed: #{resp.body}"</example>
    </pattern>
    <pattern name="response_body_keyword_in_raise" confidence="high">
      <signature>raise\s+".*response.*body</signature>
      <description>
        Broader variant catching `response` and `body` in a raise
        string. Catches patterns where the variable is named
        `response` instead of `resp`, or where nested response bodies
        are interpolated (e.g., `response['body']`). These carry the
        same risk of logging PII, PHI, or credentials.
      </description>
      <example>raise "alternate response code: #{response['statusCode']}, response body: #{response['body']}"</example>
      <example>raise "response body: #{response.body}"</example>
    </pattern>
    <pattern name="logger_with_response_body" confidence="medium">
      <signature>logger\.\w+.*\.body</signature>
      <description>
        Logging a response body via any logger method (error, warn,
        info, debug). Medium confidence because some response bodies
        are safe (e.g., static config responses), but when combined
        with external API calls to health, benefits, or OAuth
        services, this is a strong signal of PII/PHI/credential
        leakage.
      </description>
      <example>Rails.logger.error("API failed: #{resp.body}")</example>
      <example>logger.warn("Response: #{response.body}")</example>
    </pattern>
    <pattern name="params_in_meta" confidence="medium">
      <signature>meta:.*params</signature>
      <description>
        Passing raw params hash into log metadata fields. The params
        hash can contain any user-submitted data including SSNs, DOBs,
        addresses, medical information, and file uploads. Meta fields
        should use explicit allowlists of safe identifiers.
      </description>
      <example>meta: { user_data: params }</example>
      <example>meta: { request: params.to_json }</example>
    </pattern>
    <heuristic>
      A `raise` statement that interpolates `resp.body` or
      `response.body` in any method that calls an external API
      (OAuth, CHAMPVA, Pega, VES, Fitbit) is a high-priority
      violation. External API responses routinely contain
      credentials, medical records, or PII.
    </heuristic>
    <heuristic>
      A pattern of `raise "response code: #{resp.status}, response
      body: #{resp.body}"` copy-pasted across multiple API client
      files indicates systemic exposure. Check all files in the same
      module for the identical pattern.
    </heuristic>
    <heuristic>
      Any error handler that logs `e.message` where the exception
      was constructed with response body content (e.g., from a prior
      `raise "...#{resp.body}"`) propagates the same
      PII/PHI/credential data through the exception message chain.
    </heuristic>
    <false_positive>
      Logging `resp.body` for responses from internal configuration
      endpoints or health-check endpoints that return only static,
      non-sensitive data (e.g., `{ "status": "ok" }`). Acceptable
      only when the endpoint is verified to never return user data,
      credentials, or medical information.
    </false_positive>
    <false_positive>
      Using `resp.body` in test/spec code to assert response
      content. Test environments use fixture data, not real
      PII/PHI/credentials, so logging response bodies in tests is
      acceptable.
    </false_positive>
  </detection>

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

  <default_to_action>
    When you detect response body interpolation in a raise or log
    statement with high confidence, compose a PR comment that
    includes: 1. The specific violation (which line interpolates
    response body) 2. What sensitive data the response body
    contains (OAuth tokens, PHI, PII) 3. Why it matters --
    credentials in Datadog, HIPAA violation, PII exposure 4. A
    concrete code suggestion using only safe identifiers (status
    code, case_id) 5. Whether the same pattern exists in sibling
    API client files 6. A link to this play for full context Do
    not simply flag the violation -- provide the fix with safe
    identifiers replacing the response body.
  </default_to_action>

  <verify>
    <command description="No response body in raise statements in changed file">
      grep -On 'raise\s+".*resp\.body|raise\s+".*response.*body' {{file_path}} &amp;&amp; exit 1 || exit 0
    </command>
    <command description="No raw params in meta fields">
      grep -On 'meta:.*params' {{file_path}} &amp;&amp; exit 1 || exit 0
    </command>
    <command description="No logger calls with response body">
      grep -On 'logger\.\w+.*\.body' {{file_path}} &amp;&amp; exit 1 || exit 0
    </command>
    <command description="Run specs for changed file">
      bundle exec rspec {{spec_path}}
    </command>
    <command description="RuboCop passes for changed file">
      bundle exec rubocop {{file_path}}
    </command>
  </verify>

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

    [Play: Don't leak PII, PHI, or secrets](plays/dont-leak-pii-phi-secrets.md)
  </pr_comment_template>

  <anti_pattern_sources>
    <source name="Fitbit OAuth Token Logging" file="modules/dhp_connected_devices/lib/fitbit/client.rb:29" url="https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/modules/dhp_connected_devices/lib/fitbit/client.rb#L29" />
    <source name="CHAMPVA Medical Report Logging" file="modules/ivc_champva/lib/pega_api/client.rb:27, 34" url="https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/modules/ivc_champva/lib/pega_api/client.rb#L27" />
  </anti_pattern_sources>

</agent_play>
-->

# Don't Leak PII, PHI, or Secrets in Error Messages or Logs

Error messages and log output are common vectors for accidentally exposing sensitive data. This play covers how to keep PII, PHI, and secrets out of your logging infrastructure.

> [!CAUTION]
> Leaked secrets in logs can be exploited. Leaked PII/PHI violates privacy regulations and erodes user trust.

## Why It Matters

When your code logs an OAuth token to Datadog, anyone with log access gains permanent API credentials. If medical records -- diagnoses, medications, treatments -- end up in logs, that constitutes a HIPAA PHI violation with no encryption or access control protecting it. SSNs, dates of birth, and addresses appearing in logs can be found with a simple grep, violating minimum necessary access requirements. A copy-paste pattern across multiple API clients turns a single logging mistake into systemic data exposure across your entire platform.

## Guidance

The correct approach is to log only safe, non-identifying metadata -- status codes, UUIDs, internal case IDs -- and never include raw response bodies, user params, or credential-bearing data in error messages or log output.

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

[modules/dhp_connected_devices/lib/fitbit/client.rb:29](https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/modules/dhp_connected_devices/lib/fitbit/client.rb#L29)

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

##### Impact #1

Without response body scrubbing:

- OAuth `access_token` and `refresh_token` logged in plain text (permanent credentials)
- Fitbit user profile data logged: name, email, DOB, weight, health metrics (PHI under HIPAA)
- Log exfiltration attack exposes user health data + API credentials
- Leaked refresh tokens grant permanent access to user's Fitbit account
- Compliance violation: PHI in logs without encryption or access controls

With response body scrubbing:

- Only HTTP status code logged (safe, non-identifying)
- Credentials never hit logs or centralized aggregation (Datadog)
- PHI protected: health data stays in API response, never persisted in logs
- Security audit: no credential leakage vectors in log infrastructure
- Debugging still possible via status code + correlation ID

---

#### Anti-Pattern #2: Logging CHAMPVA medical report response

> **Note:** This anti-pattern appears in **5 external API client files** across IVC CHAMPVA and DHP modules:
>
> - [pega_api/client.rb:27, 34](https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/ivc_champva/lib/pega_api/client.rb#L27) - CHAMPVA medical reports
> - [ves_api/client.rb:37](https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/ivc_champva/lib/ves_api/client.rb#L37) - CHAMPVA applications
> - [llm_processor_api/client.rb:33](https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/ivc_champva/lib/llm_processor_api/client.rb#L33) - Document processing
> - [fitbit/client.rb:29, 65](https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/dhp_connected_devices/lib/fitbit/client.rb#L29) - OAuth tokens
>
> This systemic pattern suggests **copy-paste error handling** across external API integrations. All expose PHI/PII/credentials in logs.

##### Anti-Pattern

[modules/ivc_champva/lib/pega_api/client.rb:27, 34](https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/modules/ivc_champva/lib/pega_api/client.rb#L27)

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

##### Impact #2

Without response body scrubbing:

- **Systemic exposure:** Same pattern in 5 API clients means PHI/PII leakage across multiple veteran-facing services
- CHAMPVA medical reports logged: veteran diagnoses, medications, treatments (HIPAA PHI)
- Logs contain SSNs, addresses, DOBs embedded in report responses (PII)
- Double logging: both HTTP response body AND nested `response['body']` logged
- Centralized logs (Datadog) retain PHI indefinitely in searchable format
- HIPAA violation: PHI in logs accessible to engineers without "minimum necessary" access
- **Copy-paste propagation:** Pattern likely to spread to new API integrations

With response body scrubbing:

- Only `case_id` logged (safe internal identifier, no PHI)
- Medical records never touch log infrastructure
- Debugging still possible: case_id + status code + timestamp
- Compliance: logs pass HIPAA audit (no PHI, only safe metadata)
- Security: log breach doesn't expose veteran medical history
- **Reusable pattern:** Can be standardized across all external API clients

## References

- [HIPAA Security Rule](https://www.hhs.gov/hipaa/for-professionals/security/index.html)
