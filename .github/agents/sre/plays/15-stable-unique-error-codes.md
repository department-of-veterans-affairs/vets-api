---
id: stable-unique-error-codes
title: Make error codes stable, unique, and traceable
severity: HIGH
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

    [Play: Make Error Codes Stable, Unique, and Traceable](15-stable-unique-error-codes.md)
  </pr_comment_template>

</agent_play>
-->

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

#### Exceptions Config - Duplicate Error Code 108

##### Anti-Pattern

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

#### Exceptions Config - HTTP Status as Error Code

##### Anti-Pattern

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
