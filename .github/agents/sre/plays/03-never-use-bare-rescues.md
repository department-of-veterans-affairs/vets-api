---
id: bare-rescue
title: Never Use Broad or Bare Rescues
version: 2
severity: CRITICAL
category: exception-handling
tags:
- rescue
- bare-rescue
- exception-class
- apm-blackout
- error-swallowing
language: ruby
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

  <retrieval_triggers>
    <trigger>bare rescue without exception class</trigger>
    <trigger>rescue =&gt; e without specifying error type</trigger>
    <trigger>rescue Exception catches system signals</trigger>
    <trigger>catch-all error handling hides bugs from APM</trigger>
    <trigger>APM not seeing exceptions after rescue</trigger>
    <trigger>nil returned on error instead of raising</trigger>
  </retrieval_triggers>

  <detection>
    <pattern name="bare_rescue_no_class" confidence="high">
      <signature>rescue\s*$</signature>
      <description>
        Bare `rescue` on its own line with no exception class. In Ruby
        this catches StandardError and all subclasses, but signals the
        developer did not consider which specific exceptions to
        handle.
      </description>
    </pattern>
    <pattern name="rescue_hashrocket_no_class" confidence="high">
      <signature>rescue\s*=>\s*\w+</signature>
      <description>
        `rescue => e` without an exception class before the hash
        rocket. Functionally identical to bare rescue — catches all
        StandardError subclasses including NoMethodError from typos.
      </description>
    </pattern>
    <pattern name="rescue_exception_class" confidence="high">
      <signature>rescue\s+Exception\b</signature>
      <description>
        Explicitly catching `Exception`, the root of Ruby's exception
        hierarchy. This catches system signals (SignalException,
        Interrupt), process control (SystemExit), and load errors.
        Worse than bare rescue.
      </description>
    </pattern>
    <pattern name="rescue_nil_return" confidence="medium">
      <signature>rescue.*\n\s*(nil|false|\[\]|\{\})\s*$</signature>
      <description>
        A rescue block returning nil, false, empty array, or empty
        hash. When combined with bare rescue, silently swallows all
        errors.
      </description>
    </pattern>
    <heuristic>
      A `rescue` block that returns `nil`, `false`, or an empty
      collection is a strong signal of error swallowing combined
      with bare rescue.
    </heuristic>
    <heuristic>
      Methods that call external services (BGS, MPI, Lighthouse,
      Faraday-based clients) and contain bare rescue are high-
      priority violations.
    </heuristic>
    <false_positive>
      `rescue StandardError => e` at a controller action boundary or
      Sidekiq `perform` method is acceptable when it is the
      outermost handler.
    </false_positive>
    <false_positive>
      `rescue => e` in test/spec files is acceptable for testing
      error paths.
    </false_positive>
  </detection>

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

  <default_to_action>
    When detecting a bare rescue, provide a fix that narrows the
    rescue clause to specific exception classes appropriate to the
    called methods. Replace nil returns with typed exceptions.
  </default_to_action>

  <verify>
    <command description="No bare rescue remains">
      grep -On '^\s*rescue\s*$' {{file_path}} &amp;&amp; exit 1 || exit 0
    </command>
    <command description="No rescue =&gt; e without class">
      grep -On '^\s*rescue\s*=>' {{file_path}} &amp;&amp; exit 1 || exit 0
    </command>
    <command description="No rescue Exception">
      grep -On 'rescue\s+Exception\b' {{file_path}} &amp;&amp; exit 1 || exit 0
    </command>
  </verify>

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

    [Play: Never Use Broad or Bare Rescues](plays/never-use-bare-rescues.md)
  </pr_comment_template>

</agent_play>
-->

# Never Use Broad or Bare Rescues

A bare `rescue` or `rescue => e` catches every `StandardError` subclass — including `NoMethodError` from typos and `ArgumentError` from bad data. Specify the exception classes you expect.

> [!CAUTION]
> Bare `rescue` catches **everything**: `NoMethodError` from typos, `SystemExit` from `exit!`, and `SignalException` from Ctrl+C.

## Why It Matters

When you use bare `rescue`, a BGS timeout returns nil, missing data returns nil, and a `NoMethodError` from a typo returns nil — you can't tell which failure occurred. APM never sees the error, so code bugs ship to production with zero alerts. On-call sees "veteran has no file number" when the real cause is a typo in a method name. Dashboards show no errors while veterans get wrong results.

## Guidance

Always specify exception classes in `rescue` blocks. Catch only the exceptions the called code can raise — typically service-specific errors and `Faraday::Error` subclasses. Use `rescue StandardError` only at controller action or Sidekiq `perform` boundaries as a last-resort handler.

### Do

- `rescue BGS::ServiceError, Faraday::Error => e` — catches only expected failures
- `rescue StandardError => e` at controller boundary — outermost handler only

### Don't

- `rescue` (bare) — catches everything including typos and system signals
- `rescue => e` — identical to bare rescue, just assigns the exception
- `rescue Exception` — catches `Interrupt`, `SystemExit`, and load errors

## Anti-Patterns

### VRE Veteran Claim

**Source:** [modules/vre/.../vre_veteran_readiness_employment_claim.rb:254-257](https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/modules/vre/app/models/vre/vre_veteran_readiness_employment_claim.rb#L254-L257)

```ruby
def veteran_va_file_number(user)
  response = ::BGS::People::Request.new.find_person_by_participant_id(user:)
  response.file_number
rescue  # Bare rescue catches ALL exceptions
  Rails.logger.warn('VRE claim unable to add VA File Number.', { user_uuid: user&.uuid })
  nil  # Returns nil for ALL failures
end
```

**Problem:** Bare `rescue` catches `NoMethodError` from typos, `SystemExit`, and `SignalException`. Returns nil for every failure — a BGS timeout is indistinguishable from "no file number." APM never sees the error.

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

**Source:** [modules/simple_forms_api/.../cemeteries_controller.rb:14-17](https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/modules/simple_forms_api/app/controllers/simple_forms_api/v1/cemeteries_controller.rb#L14-L17)

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

**Problem:** `rescue => e` catches all `StandardError` subclasses. Manual backtrace logging duplicates APM. A typo in `format_cemetery` returns the same generic 500 as a network timeout — no diagnostic precision.

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

**Source:** [lib/saml/user.rb:79-82](https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/lib/saml/user.rb#L79-L82)

```ruby
def authn_context
  saml_response.authn_context_text
rescue  # Bare rescue catches everything just to set Sentry tags
  Sentry.set_tags(controller_name: 'sessions', sign_in_method: 'not-signed-in:error')
  raise  # Re-raises after catching — tags ALL exceptions including bugs
end
```

**Problem:** Bare rescue catches and tags all exceptions — a `NoMethodError` gets tagged as "not-signed-in:error," which is misleading. Sentry dashboards can't distinguish SAML errors from code bugs.

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

## References

- [RuboCop Style/RescueException](https://docs.rubocop.org/rubocop/cops_style.html#stylerescueexception)
- [RuboCop Style/RescueStandardError](https://docs.rubocop.org/rubocop/cops_style.html#stylerescuestandarderror)
- [Ruby Exception Hierarchy](https://ruby-doc.org/core/Exception.html)
