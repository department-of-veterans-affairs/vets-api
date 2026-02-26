---
id: validate-at-boundaries
title: Validate before you fail (fail early, not late)
severity: HIGH
---

<!--
<agent_play>

  <context>
    A 50MB file upload begins processing, then discovers an invalid
    form_number and must roll back, wasting bandwidth, storage, and
    time. An untyped raise of "Missing param" returns 500, making the
    client think the server crashed when the actual problem is a missing
    parameter that should return 400. When validation happens late in a
    helper, the database has already been written to, so a validation
    failure requires a manual rollback of mutated state. Failing late
    costs resources while failing early costs only milliseconds, so
    checking params before processing starts avoids irreversible waste.
  </context>

  <applies_to>
    <glob>app/controllers/**/*.rb</glob>
    <glob>modules/*/app/controllers/**/*.rb</glob>
    <glob>app/sidekiq/**/*.rb</glob>
    <glob>modules/*/app/sidekiq/**/*.rb</glob>
  </applies_to>

  <related_plays>
    <play id="prefer-typed-exceptions" relationship="complementary" />
    <play id="classify-errors" relationship="complementary" />
  </related_plays>

  <rules>
    <rule enforcement="must">
      Validate all inputs at the controller boundary before any
      state change (file uploads, DB writes, API calls).
    </rule>
    <rule enforcement="must">
      Use typed exceptions for validation failures
      (ParameterMissing, UnprocessableEntity) — never untyped string
      raises.
    </rule>
    <rule enforcement="must_not">
      Never defer parameter validation to helper methods called
      after state mutation has begun.
    </rule>
    <rule enforcement="must_not">
      Never mutate state (upload files, write to database, call
      APIs) before validation completes.
    </rule>
    <rule enforcement="should">
      Use Rails strong parameters or before_action callbacks for
      boundary validation.
    </rule>
    <rule enforcement="verify">
      All validation at controller boundary (no late validation in
      helpers)
    </rule>
    <rule enforcement="verify">
      No state changes before validation completes
    </rule>
    <rule enforcement="verify">
      Validation errors return 4xx (not 500)
    </rule>
    <rule enforcement="verify">
      Tests verify validation happens before processing
    </rule>
  </rules>

  <investigate_before_answering>
    <step>Read the full controller action to understand the order of operations — what state mutations (file uploads, DB writes, API calls) occur before validation.</step>
    <step>Identify all parameters being validated and where validation currently happens (in the action body, in a helper method, in a before_action callback).</step>
    <step>Determine what typed exception classes are available in the module's namespace or in `Common::Exceptions` for the validation errors being raised.</step>
    <step>Check if Rails strong parameters (`params.require`) could handle the validation automatically instead of custom validation methods.</step>
    <step>Verify whether moving validation earlier would break any dependency ordering (e.g., a parameter that depends on a value set by an earlier operation). Do not suggest moving validation without understanding the full action flow. The correct fix depends on what state mutations occur and in what order.</step>
  </investigate_before_answering>

  <severity_assessment>
    <critical>validation happens after file upload processing in a
controller handling veteran document submissions</critical>
    <critical>late validation in code that mutates financial or benefits
data before checking parameters</critical>
    <high>untyped raise for missing parameters in any controller action</high>
    <high>validation deferred to helper method called after database
writes or API calls</high>
    <medium>validation in getter method that is called before any state
mutation</medium>
  </severity_assessment>

  <pr_comment_template>
    **Validate before you fail (fail early, not late)** | `HIGH`

    `{{file_path}}:{{line_number}}` — {{one_line_violation_description}}

    **Why this matters:** Late validation wastes resources (file uploads, DB writes,
    API calls) before discovering invalid input. Untyped `raise 'string'` returns
    500 instead of the correct 4xx status code, misleading clients and inflating
    server error metrics.

    **Suggested fix:**
    ```ruby
    {{suggested_code}}
    ```

    - [ ] Validation happens before any state mutation
    - [ ] Uses typed exception (ParameterMissing, UnprocessableEntity)
    - [ ] Returns correct 4xx status code (not 500)
    - [ ] No side effects occur before validation completes

    [Play: Validate before you fail](plays/validate-at-boundaries-fail-fast.md)
  </pr_comment_template>

</agent_play>
-->

### Do

- Validate all inputs at the controller boundary before any state change:
  ```ruby
  def upload
    validate_form_number!  # Validate FIRST
    form_id = FORM_NUMBER_MAP[params[:form_number]]
    # ... proceed with file processing
  end
  ```
- Use typed exceptions for validation failures (`ParameterMissing`, `UnprocessableEntity`):
  ```ruby
  raise Common::Exceptions::ParameterMissing, 'form_number' if params[:form_number].blank?
  raise Common::Exceptions::UnprocessableEntity.new(
    code: 'INVALID_FORM_NUMBER',
    detail: 'Form number not recognized'
  ) unless FORM_NUMBER_MAP.key?(params[:form_number])
  ```
- Use Rails strong parameters or `before_action` callbacks:
  ```ruby
  before_action :validate_form_number!, only: [:upload]
  ```

### Don't

- Defer parameter validation to helper methods called after state mutation:
  ```ruby
  # BAD: get_form_id called after file upload has started
  def upload
    process_file(params[:file])
    form_id = get_form_id  # validation happens too late
  end
  ```
- Mutate state before validation completes:
  ```ruby
  # BAD: database write happens before params are checked
  record = Record.create!(data: params[:data])
  validate_params!  # too late -- record already created
  ```
- Use untyped string raises (`raise 'Missing param'`) for validation:
  ```ruby
  # BAD: RuntimeError returns 500 instead of 400/422
  raise 'Missing/malformed form_number in params'
  ```

## Anti-Patterns

#### IVC CHAMPVA Late Validation

##### Anti-Pattern

```ruby
def get_form_id
  form_number = params[:form_number]
  raise 'Missing/malformed form_number in params' unless form_number  # Validates late, after other work
  # Untyped exception: 'raise string' → RuntimeError → 500 instead of 400
  FORM_NUMBER_MAP[form_number]
end
```

##### Golden Pattern

```ruby
def upload
  validate_form_number!  # Validate FIRST, before any file processing
  form_id = FORM_NUMBER_MAP[params[:form_number]]
  # ... proceed with file processing
end

private

def validate_form_number!
  raise Common::Exceptions::ParameterMissing, 'form_number' if params[:form_number].blank?
  raise Common::Exceptions::UnprocessableEntity.new(
    code: 'INVALID_FORM_NUMBER',
    detail: 'Form number not recognized'
  ) unless FORM_NUMBER_MAP.key?(params[:form_number])
end
```
