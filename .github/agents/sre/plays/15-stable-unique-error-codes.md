# Play 15: Make Error Codes Stable, Unique, and Traceable

## Context
When error code 108 means three different things, a client checking `if (code === 108)` matches unrelated errors and breaks downstream error handling. APM shows "108 errors spiking" but there is no way to tell whether it is a missing param, an ambiguous request, or a third issue, causing incident chaos. An error code that mirrors the HTTP status (e.g., `code: 422`) breaks client code when the status changes to 400, because the code is not stable.

## Applies To
- `config/locales/exceptions.en.yml`
- `lib/common/exceptions/**/*.rb`
- `modules/*/lib/*/exceptions/**/*.rb`

## Investigation Steps
1. Read the full exceptions.en.yml file and build a frequency map of all `code:` values. Identify which codes appear more than once and under which exception keys.
2. Determine whether duplicate codes are intentional aliases (same semantic error) or distinct error conditions that should have different codes.
3. Check whether any `code:` value matches its corresponding `status:` value, indicating HTTP-status-as-code.
4. Review client code or API documentation to understand which codes clients currently rely on -- changing an existing code breaks backward compatibility.
5. Check the module's exception classes in `lib/common/exceptions/` and `modules/*/lib/*/exceptions/` to understand how codes are referenced in Ruby. Do not suggest renumbering codes without understanding client dependencies. Existing codes are part of the API contract.

## Severity Assessment
- **CRITICAL:** Duplicate error codes in exceptions config where clients actively switch on the code value
- **CRITICAL:** Error code used as HTTP status causes client breakage when status changes
- **HIGH:** New exception added with a code that duplicates an existing code in exceptions.en.yml
- **HIGH:** Error code equals HTTP status value (code: 422, status: 422)
- **MEDIUM:** Numeric code without namespace prefix in a module-specific exception

## Golden Patterns

### Do
Assign unique codes to each distinct error condition:
```yaml
parameter_missing:
  code: 108
  status: 400

ambiguous_request:
  code: 111   # Different error, different code
  status: 400
```

Use namespaced string codes (e.g., `PAWS_DUPLICATE_APPLICATION`):
```yaml
paws_duplicate_application:
  code: PAWS_DUPLICATE_APPLICATION
  status: 422
```

Keep codes stable -- never change once assigned.

### Don't
Use HTTP status code as the error code value:
```yaml
# Violation: code mirrors status
unprocessable_entity:
  code: 422
  status: 422
```

Reuse the same code for different error conditions:
```yaml
# Violation: three different errors, same code
parameter_missing:
  code: 108
ambiguous_request:
  code: 108   # duplicate!
```

Use purely numeric codes without namespace prefix for module-specific exceptions.

## Anti-Patterns

### Duplicate Error Code 108
**Anti-pattern:**
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
**Problem:** Clients cannot distinguish between "missing parameter" (108) and "ambiguous request" (also 108). APM dashboards aggregate three distinct failure modes under one code. Incident response becomes ambiguous.

**Corrected:**
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

### HTTP Status as Error Code
**Anti-pattern:**
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
**Problem:** Using `422` as the error code violates the principle that codes should be semantic, not just HTTP status. Cannot distinguish between local validation failures vs upstream service rejections. Code is not stable: if you later decide to return 400 instead of 422, the error code changes.

**Corrected:**
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

## Finding Template
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

## Verify Commands
```bash
# Find duplicate code values in exceptions config
awk '/^\s*code:/ {codes[$NF]++} END {for (c in codes) if (codes[c]>1) {print c, codes[c]; err=1} if(err) exit 1}' config/locales/exceptions.en.yml

# Find code values matching HTTP status patterns (3-digit codes equal to status)
grep -On 'code:\s*\d{3}\s*$' config/locales/exceptions.en.yml

# Run specs for exception handling
bundle exec rspec spec/lib/common/exceptions/ spec/requests/
```

## Related Plays
- Play: standardized-error-responses (complementary)
- Play: classify-errors (complementary)
