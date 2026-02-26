---
id: bare-rescue
title: Never Use Broad or Bare Rescues
severity: CRITICAL
---

<!--
<agent_play>

  <context>
    A bare rescue swallows everything: typos become nil, Ctrl+C hangs
    processes, and SystemExit is ignored. APM never sees the error, so
    code bugs ship to production with zero alerts and zero visibility. A
    BGS timeout returns nil, missing data returns nil, and a database
    error returns nil, making it impossible to tell which failure
    occurred. A NoMethodError from a code bug looks like "veteran has no
    file number," leading to the wrong diagnosis and the wrong fix.
  </context>

  <applies_to>
    <glob>app/controllers/**/*.rb</glob>
    <glob>app/sidekiq/**/*.rb</glob>
    <glob>app/models/**/*.rb</glob>
    <glob>modules/*/app/controllers/**/*.rb</glob>
    <glob>modules/*/app/models/**/*.rb</glob>
    <glob>modules/*/app/sidekiq/**/*.rb</glob>
    <glob>lib/**/*.rb</glob>
  </applies_to>

  <related_plays>
    <play id="dont-swallow-errors" relationship="complementary" />
    <play id="preserve-cause-chains" relationship="complementary" />
    <play id="classify-errors" relationship="complementary" />
    <play id="dont-catch-log-reraise" relationship="complementary" />
  </related_plays>

  <rules>
    <rule enforcement="must">
      Always specify exception classes in rescue blocks.
    </rule>
    <rule enforcement="must_not">
      Never use bare `rescue` (catches everything including typos).
    </rule>
    <rule enforcement="must_not">
      Never use `rescue => e` without an exception class.
    </rule>
    <rule enforcement="must_not">
      Never use `rescue Exception` (catches system signals).
    </rule>
    <rule enforcement="should">
      Use `rescue StandardError` only at controller/job boundaries.
    </rule>
    <rule enforcement="verify">
      Tests verify correct exceptions are caught
    </rule>
    <rule enforcement="verify">
      APM can see code bugs (NoMethodError, ArgumentError)
    </rule>
  </rules>

  <investigate_before_answering>
    <step>Read the full method to understand what code is protected</step>
    <step>Identify exception types the called methods can raise</step>
    <step>Determine if at boundary (controller/job) or inner code</step>
    <step>Check if typed exceptions exist in the module's namespace</step>
    <step>Check what callers expect — nil returns or exceptions</step>
  </investigate_before_answering>

  <severity_assessment>
    <critical>bare rescue in code handling PII, PHI, or financial data</critical>
    <critical>bare rescue in controller actions handling user requests</critical>
    <critical>bare rescue + nil return in code calling external services</critical>
    <high>bare rescue in service layer calling external APIs</high>
    <medium>bare rescue in internal utility with no external dependencies</medium>
  </severity_assessment>

  <pr_comment_template>
    **Never Use Broad or Bare Rescues** | `CRITICAL`

    `{{file_path}}:{{line_number}}` — `{{rescue_pattern}}` catches all exceptions
    including `NoMethodError` from typos. APM cannot see errors caught this way.

    **Why this matters:** All failures return the same result. On-call can't
    distinguish service outage from code bug. BGS timeout looks like "no file number."

    **Suggested fix:**
    ```ruby
    {{suggested_code}}
    ```

    - [ ] Rescue specifies exception class(es)
    - [ ] No nil/false return for failures
    - [ ] Cause chain preserved with `cause: e`

    [Play: Never Use Broad or Bare Rescues](03-never-use-bare-rescues.md)
  </pr_comment_template>

</agent_play>
-->

### Do

- `rescue BGS::ServiceError, Faraday::Error => e` — catches only expected failures
- `rescue StandardError => e` at controller boundary — outermost handler only

### Don't

- `rescue` (bare) — catches everything including typos and system signals
- `rescue => e` — identical to bare rescue, just assigns the exception
- `rescue Exception` — catches `Interrupt`, `SystemExit`, and load errors

## Anti-Patterns

### VRE Veteran Claim

```ruby
def veteran_va_file_number(user)
  response = ::BGS::People::Request.new.find_person_by_participant_id(user:)
  response.file_number
rescue  # Bare rescue catches ALL exceptions
  Rails.logger.warn('VRE claim unable to add VA File Number.', { user_uuid: user&.uuid })
  nil  # Returns nil for ALL failures
end
```

**Corrected:**

```ruby
def veteran_va_file_number(user)
  response = ::BGS::People::Request.new.find_person_by_participant_id(user:)
  response.file_number
rescue BGS::ServiceError, Faraday::Error => e
  Rails.logger.warn('BGS unavailable', { user_uuid: user&.uuid, error: e.class })
  raise Common::Exceptions::ServiceUnavailable.new(cause: e)
end
```

### Cemeteries Controller

```ruby
def index
  cemeteries = SimpleFormsApi::CemeteryService.all
  render json: { data: cemeteries.map { |cemetery| format_cemetery(cemetery) } }
rescue => e  # Same as bare rescue — catches EVERYTHING
  Rails.logger.error "Cemetery controller error: #{e.message}"
  Rails.logger.error e.backtrace.join("\n")
  render json: { error: 'Unable to load cemetery data' }, status: :internal_server_error
end
```

**Corrected:**

```ruby
def index
  cemeteries = SimpleFormsApi::CemeteryService.all
  render json: { data: cemeteries.map { |cemetery| format_cemetery(cemetery) } }
rescue SimpleFormsApi::ServiceError, Faraday::Error => e
  render_api_exception(e)
end
# NoMethodError raises to APM — code bugs visible
```

### SAML User

```ruby
def authn_context
  saml_response.authn_context_text
rescue  # Bare rescue catches everything just to set Sentry tags
  Sentry.set_tags(controller_name: 'sessions', sign_in_method: 'not-signed-in:error')
  raise  # Re-raises after catching — tags ALL exceptions including bugs
end
```

**Corrected:**

```ruby
def authn_context
  saml_response.authn_context_text
rescue SAML::ValidationError, SAML::MissingAttributeError => e
  Sentry.set_tags(controller_name: 'sessions', sign_in_method: 'not-signed-in:saml-error')
  raise
end
# Unexpected errors raise without misleading tags
```
