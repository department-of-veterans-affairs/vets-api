---
id: stable-unique-error-codes
title: Make error codes stable, unique, and traceable
version: 1
severity: HIGH
category: api-design
tags:
- error-codes
- uniqueness
- stability
- i18n
- exceptions-config
language: ruby
---

<!--
<agent_play>

  <context>
    When error code 108 means three different things, a client checking
    `if (code === 108)` matches unrelated errors and breaks downstream
    error handling. APM shows "108 errors spiking" but there is no way
    to tell whether it is a missing param, an ambiguous request, or a
    third issue, causing incident chaos. An error code that mirrors the
    HTTP status (e.g., `code: 422`) breaks client code when the status
    changes to 400, because the code is not stable. When local
    validation and upstream rejection both return the same error code,
    you cannot tell who failed and metrics become useless.
  </context>

  <applies_to>
    <glob>config/locales/exceptions.en.yml</glob>
    <glob>lib/common/exceptions/**/*.rb</glob>
    <glob>modules/*/lib/*/exceptions/**/*.rb</glob>
  </applies_to>

  <related_plays>
    <play id="standardized-error-responses" relationship="complementary" />
    <play id="classify-errors" relationship="complementary" />
  </related_plays>

  <retrieval_triggers>
    <trigger>duplicate error codes in exceptions config</trigger>
    <trigger>error code same as HTTP status code</trigger>
    <trigger>multiple errors share same code number</trigger>
    <trigger>error code changes when HTTP status changes</trigger>
    <trigger>cannot distinguish error types by code</trigger>
  </retrieval_triggers>

  <detection>
    <pattern name="duplicate_code_values_in_yaml" confidence="high">
      <signature>code:\s*(\d+)</signature>
      <description>
        Matches `code:` directives in the exceptions YAML config. When
        the same numeric value appears on multiple exception keys, it
        indicates duplicate error codes. The agent should collect all
        `code:` values in exceptions.en.yml and flag any value that
        appears more than once across different exception keys.
      </description>
      <example>code: 108` appearing under both `parameter_missing` and `ambiguous_request</example>
      <example>code: 422` appearing under both `unprocessable_entity` and `upstream_unprocessable_entity</example>
    </pattern>
    <pattern name="http_status_as_error_code" confidence="medium">
      <signature>code:\s*\d{3}\s*$</signature>
      <description>
        A `code:` value that is exactly a 3-digit number matching
        common HTTP status codes (400, 401, 403, 404, 422, 500, 502,
        503, 504). When the code value matches the `status:` value on
        a nearby line, it indicates the developer used the HTTP status
        as the error code rather than assigning a unique semantic
        code. Medium confidence because some 3-digit codes may be
        intentional unique identifiers that happen to be 3 digits.
      </description>
      <example>code: 422` with `status: 422` on the next line</example>
      <example>code: 400` with `status: 400` on a nearby line</example>
    </pattern>
    <pattern name="non_namespaced_numeric_code" confidence="medium">
      <signature>code:\s*\d+\s*$</signature>
      <description>
        A purely numeric error code without a domain namespace prefix.
        Numeric codes are harder to trace to their source module and
        are more likely to collide across teams. Medium confidence
        because existing numeric codes may be intentional and well-
        documented in the registry.
      </description>
      <example>code: 108</example>
      <example>code: 999</example>
    </pattern>
    <heuristic>
      When reviewing exceptions.en.yml, collect all `code:` values
      into a frequency map. Any code value appearing more than once
      under different exception keys is a duplicate code violation.
      Exception: two keys that represent the same semantic error
      (e.g., `parameter_missing` and `parameters_missing`) may share
      a code.
    </heuristic>
    <heuristic>
      When a `code:` value is identical to the `status:` value in
      the same exception block, the developer likely copied the HTTP
      status as the error code. Check whether the code would remain
      meaningful if the HTTP status changed.
    </heuristic>
    <heuristic>
      When a module defines new exception classes in
      `lib/*/exceptions/`, check that each class references a unique
      code in exceptions.en.yml. New exceptions that reuse existing
      codes from other modules indicate a namespace collision.
    </heuristic>
    <false_positive>
      Two exception keys that represent the exact same semantic
      error (e.g., `parameter_missing` and `parameters_missing` both
      meaning "a required parameter is absent") may intentionally
      share the same code. This is acceptable only when the keys are
      aliases for the same condition, not when they represent
      distinct error scenarios.
    </false_positive>
    <false_positive>
      A 3-digit numeric code like `code: 108` that happens to look
      like an HTTP status but is actually a well-documented unique
      identifier in the error code registry. Verify against the
      registry before flagging.
    </false_positive>
  </detection>

  <rules>
    <rule enforcement="must">
      Error codes must be unique across the system — no two distinct
      error conditions may share the same code value in
      exceptions.en.yml.
    </rule>
    <rule enforcement="must">
      Error codes must be stable — once assigned, a code value must
      never change, be reused for a different error, or be retired.
    </rule>
    <rule enforcement="must_not">
      Never use an HTTP status code as the error code value — codes
      must be independent of transport status so they remain stable
      when status changes.
    </rule>
    <rule enforcement="should">
      Use namespaced string codes for domain specificity (e.g.,
      `PAWS_DUPLICATE_APPLICATION`, `CLAIMS_MISSING_SSN`) to prevent
      cross-team collisions.
    </rule>
    <rule enforcement="should">
      Document all error codes in the central registry
      (config/locales/exceptions.en.yml) with descriptive titles and
      details.
    </rule>
    <rule enforcement="verify">
      Grep for duplicate codes in exceptions.en.yml (no matches)
    </rule>
    <rule enforcement="verify">
      Client can handle by code: `case 'PAWS_DUPLICATE'`
    </rule>
    <rule enforcement="verify">
      APM can track specific error trends (not ambiguous aggregates)
    </rule>
    <rule enforcement="verify">
      Changing HTTP status doesn't change error code
    </rule>
  </rules>

  <investigate_before_answering>
    <step>Read the full exceptions.en.yml file and build a frequency map of all `code:` values. Identify which codes appear more than once and under which exception keys.</step>
    <step>Determine whether duplicate codes are intentional aliases (same semantic error) or distinct error conditions that should have different codes.</step>
    <step>Check whether any `code:` value matches its corresponding `status:` value, indicating HTTP-status-as-code.</step>
    <step>Review client code or API documentation to understand which codes clients currently rely on — changing an existing code breaks backward compatibility.</step>
    <step>Check the module's exception classes in `lib/common/exceptions/` and `modules/*/lib/*/exceptions/` to understand how codes are referenced in Ruby. Do not suggest renumbering codes without understanding client dependencies. Existing codes are part of the API contract.</step>
  </investigate_before_answering>

  <severity_assessment>
    <critical>duplicate error codes in exceptions config where clients
actively switch on the code value</critical>
    <critical>error code used as HTTP status causes client breakage when
status changes</critical>
    <high>new exception added with a code that duplicates an existing
code in exceptions.en.yml</high>
    <high>error code equals HTTP status value (code: 422, status: 422)</high>
    <medium>numeric code without namespace prefix in a module-specific
exception</medium>
  </severity_assessment>

  <default_to_action>
    When you detect a duplicate or unstable error code, compose a
    PR comment that includes: 1. The specific violation (which
    codes are duplicated or which code matches HTTP status) 2. Why
    it matters (clients cannot distinguish errors, metrics are
    ambiguous, codes break when status changes) 3. A concrete
    suggestion for a unique replacement code following the
    namespace convention 4. A reminder that existing codes are
    part of the API contract and may require client migration 5. A
    link to this play for full context
  </default_to_action>

  <verify>
    <command description="Find duplicate code values in exceptions config">
      awk '/^\s*code:/ {codes[$NF]++} END {for (c in codes) if (codes[c]>1) {print c, codes[c]; err=1} if(err) exit 1}' config/locales/exceptions.en.yml
    </command>
    <command description="Find code values matching HTTP status patterns (3-digit codes equal to status)">
      grep -On 'code:\s*\d{3}\s*$' config/locales/exceptions.en.yml
    </command>
    <command description="Run specs for exception handling">
      bundle exec rspec spec/lib/common/exceptions/ spec/requests/
    </command>
  </verify>

  <pr_comment_template>
    **Make Error Codes Stable, Unique, and Traceable** | `HIGH`

    `{{file_path}}:{{line_number}}` -- {{one_line_violation_description}}

    **Why this matters:** {{why_it_matters_summary}}

    **Suggested fix:**
    ```yaml
    {{suggested_code}}
    ```

    **Verify:**
    - [ ] No two distinct errors share the same code value
    - [ ] Code is not identical to HTTP status
    - [ ] Code follows namespace convention (MODULE_ERROR_NAME)
    - [ ] Existing clients are not broken by the change

    [Play: Make Error Codes Stable, Unique, and Traceable](plays/stable-unique-error-codes.md)
  </pr_comment_template>

  <anti_pattern_sources>
    <source name="Duplicate Error Code 108" file="config/locales/exceptions.en.yml:75-86, 237-242" url="https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/config/locales/exceptions.en.yml#L75-L86" />
    <source name="HTTP Status as Error Code" file="config/locales/exceptions.en.yml:156-167" url="https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/config/locales/exceptions.en.yml#L156-L167" />
  </anti_pattern_sources>

</agent_play>
-->

# Make error codes stable, unique, and traceable

Every distinct error condition needs its own code that never changes. Stable, unique codes let clients handle errors precisely and let APM track each failure mode independently.

> [!CAUTION]
> Duplicate error codes make client error handling and APM tracking ambiguous — you can't tell which error occurred.

## Why It Matters

When error code 108 means three different things, a client checking `if (code === 108)` matches unrelated errors and breaks downstream handling. APM shows "108 errors spiking" but you cannot tell whether it is a missing param, an ambiguous request, or something else entirely — incident response becomes guesswork. If you use the HTTP status code as your error code (e.g., `code: 422`), the code breaks when you change the status to 400. When local validation and upstream rejection both return the same code, you lose the ability to tell who failed and your metrics become useless.

## Guidance

Assign a unique, stable code to every distinct error condition. Use namespaced string codes (e.g., `PAWS_DUPLICATE_APPLICATION`) to prevent collisions across teams. Never reuse a code for a different error, and never tie the code value to the HTTP status — codes must survive transport changes.

### Do

- Assign unique codes to each distinct error condition:
  ```yaml
  parameter_missing:
    code: 108
    status: 400

  ambiguous_request:
    code: 111   # Different error, different code
    status: 400
  ```
- Use namespaced string codes (e.g., `PAWS_DUPLICATE_APPLICATION`):
  ```yaml
  paws_duplicate_application:
    code: PAWS_DUPLICATE_APPLICATION
    status: 422
  ```
- Keep codes stable — never change once assigned

### Don't

- Use HTTP status code as the error code value:
  ```yaml
  # Violation: code mirrors status
  unprocessable_entity:
    code: 422
    status: 422
  ```
- Reuse the same code for different error conditions:
  ```yaml
  # Violation: three different errors, same code
  parameter_missing:
    code: 108
  ambiguous_request:
    code: 108   # duplicate!
  ```
- Use purely numeric codes without namespace prefix for module-specific exceptions

## Anti-Patterns

### Anti-Patterns from vets-api

#### Exceptions Config - Duplicate Error Code 108

##### Anti-Pattern

[config/locales/exceptions.en.yml:75-86, 237-242](https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/config/locales/exceptions.en.yml#L75-L86)

```yaml
parameter_missing:
  title: Missing parameter
  detail: "The required parameter \"%{param}\", is missing"
  code: 108   # Duplicate!
  status: 400

parameters_missing:
  title: Missing parameter
  code: 108   # Same code, different exception key
  status: 400

ambiguous_request:
  title: Ambiguous Request
  detail: "%{detail}"
  code: 108   # Same code, completely different error!
  status: 400
```

##### Golden Pattern

```yaml
parameter_missing:
  title: Missing parameter
  detail: "The required parameter \"%{param}\", is missing"
  code: 108   # Unique code
  status: 400

parameters_missing:
  title: Missing parameters
  code: 108   # OK - same semantic error as parameter_missing
  status: 400

ambiguous_request:
  title: Ambiguous Request
  detail: "%{detail}"
  code: 111   # New unique code
  status: 400
```

##### Impact

Without unique error codes:

- Clients cannot distinguish between "missing parameter" (108) and "ambiguous request" (also 108)
- APM dashboards aggregate three distinct failure modes under one code
- Incident response becomes ambiguous: "We're seeing code 108 errors" → "Which 108? parameter_missing or ambiguous_request?"
- Client-side error handling breaks: `if (error.code === 108)` matches multiple unrelated errors

With unique error codes:

- Each distinct error condition has its own code
- APM can track trends: "ambiguous_request errors spiking" vs "parameter_missing stable"
- Client can handle specifically: `case 108: showMissingParam(); case 111: showAmbiguousRequest()`
- Incident response is clear: "Code 111 spike → check for ambiguous requests"

---

#### Exceptions Config - HTTP Status as Error Code

##### Anti-Pattern

[config/locales/exceptions.en.yml:156-167](https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/config/locales/exceptions.en.yml#L156-L167)

```yaml
unprocessable_entity:
  title: Unprocessable Entity
  detail: The request was well-formed but was unable to be followed due to semantic or validation errors
  code: 422   # HTTP status code used as error code
  status: 422

upstream_unprocessable_entity:
  title: Unprocessable Entity
  detail: The request was well-formed but was unable to be followed due to semantic or validation errors
  code: 422   # Same code, but upstream vs local distinction lost
  status: 422
```

##### Golden Pattern

```yaml
unprocessable_entity:
  title: Unprocessable Entity
  detail: The request was well-formed but was unable to be followed due to semantic or validation errors
  code: VALIDATION_FAILED   # Semantic code (or numeric: 109)
  status: 422

upstream_unprocessable_entity:
  title: Upstream Unprocessable Entity
  detail: Upstream service rejected the request
  code: UPSTREAM_VALIDATION_FAILED   # Distinct semantic code (or: 119)
  status: 422
```

##### Impact

Without semantic error codes:

- Using `422` as the error code violates the principle that codes should be semantic, not just HTTP status
- Cannot distinguish between local validation failures vs upstream service rejections
- APM metrics blind spot: "how many errors were upstream vs local?" cannot be answered
- Code is not stable: if we later decide to return 400 instead of 422, the error code changes

With semantic error codes:

- Error codes are independent of HTTP status (status can evolve, code stays stable)
- Can track "local validation errors" separately from "upstream validation errors"
- Clients can handle: `if (code === 'VALIDATION_FAILED')` vs `if (code === 'UPSTREAM_VALIDATION_FAILED')`
- Future-proof: changing HTTP status from 422 → 400 doesn't break client code

## References

- [vets-api exceptions.en.yml](https://github.com/department-of-veterans-affairs/vets-api/blob/master/config/locales/exceptions.en.yml)
