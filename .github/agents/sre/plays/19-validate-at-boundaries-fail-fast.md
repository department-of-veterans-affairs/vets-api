---
id: validate-at-boundaries
title: Validate before you fail (fail early, not late)
version: 1
severity: HIGH
category: api-design
tags:
- validation
- fail-fast
- boundary
- parameter-checking
- early-return
language: ruby
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

  <retrieval_triggers>
    <trigger>validation happens late after state mutation</trigger>
    <trigger>file upload completes before discovering invalid input</trigger>
    <trigger>raise string for missing parameter returns 500</trigger>
    <trigger>validate inputs early at controller boundary</trigger>
    <trigger>fail fast before processing starts</trigger>
  </retrieval_triggers>

  <detection>
    <pattern name="untyped_raise_missing_param" confidence="high">
      <signature>raise\s+['"].*missing.*param</signature>
      <description>
        Untyped `raise 'string'` for missing parameters. In Ruby,
        `raise 'message'` creates a generic RuntimeError that falls
        through to the 500 handler, even though a missing parameter is
        a client error (400/422). This pattern indicates late
        validation using string raises instead of typed exceptions at
        the boundary. Case insensitive match.
      </description>
      <example>raise 'Missing/malformed form_number in params'</example>
      <example>raise "Missing required parameter"</example>
    </pattern>
    <pattern name="untyped_raise_malformed" confidence="high">
      <signature>raise\s+['"].*malformed</signature>
      <description>
        Untyped `raise 'string'` for malformed input. Same issue as
        missing param pattern — a string raise becomes RuntimeError
        and returns 500 instead of the correct 400/422 client error
        status. Case insensitive match.
      </description>
      <example>raise 'Missing/malformed form_number in params'</example>
      <example>raise "Malformed request body"</example>
    </pattern>
    <pattern name="late_validation_in_getter" confidence="medium">
      <signature>def\s+get_\w+.*\n.*params\[.*\n.*raise\s+['"]</signature>
      <description>
        A getter method that reads from params and then raises with a
        string. This pattern indicates validation deferred into a
        helper method instead of being performed at the controller
        boundary before any processing starts. Medium confidence
        because the agent should check whether the getter is called
        before or after state mutations.
      </description>
      <example>def get_form_id\n  form_number = params[:form_number]\n  raise 'Missing...'</example>
    </pattern>
    <heuristic>
      A controller action that performs file uploads, database
      writes, or API calls before calling a validation or getter
      method is a strong signal of late validation. Look for
      `upload`, `save`, `create`, or HTTP client calls appearing
      before any parameter checks.
    </heuristic>
    <heuristic>
      A helper or private method that reads `params[...]` and raises
      with a string message suggests validation was pushed into a
      utility method rather than being performed at the controller
      boundary.
    </heuristic>
    <heuristic>
      Methods named `get_*` or `fetch_*` that contain `raise
      'string'` for missing params indicate validation mixed into
      data retrieval instead of being separated into an explicit
      validation step.
    </heuristic>
    <false_positive>
      Typed exception raises in getter methods are acceptable when
      the getter is called at the very start of the controller
      action before any state mutation. For example, `raise
      Common::Exceptions::ParameterMissing` in a helper called as
      the first line of an action is not a violation of this play.
    </false_positive>
    <false_positive>
      Validation in `before_action` callbacks is acceptable because
      Rails executes these before the controller action body. This
      is effectively boundary validation even though it may live in
      a separate method.
    </false_positive>
    <false_positive>
      Strong parameters (`params.require(:key)`) raise
      `ActionController::ParameterMissing` automatically, which is a
      typed exception. This is the Rails-recommended approach and is
      not a violation.
    </false_positive>
  </detection>

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

  <default_to_action>
    When you detect a late validation or untyped parameter raise
    with high confidence, compose a PR comment that includes: 1.
    The specific violation (where validation happens vs. where
    state mutation starts) 2. Why it matters (wasted resources,
    wrong HTTP status code, misleading error) 3. A concrete code
    suggestion moving validation to the boundary with typed
    exceptions 4. The verification checklist items relevant to
    this specific case 5. A link to this play for full context
  </default_to_action>

  <verify>
    <command description="No untyped raise for missing params in changed file">
      grep -Pni 'raise\s+['"'"'"].*missing.*param' {{file_path}} &amp;&amp; exit 1 || exit 0
    </command>
    <command description="No untyped raise for malformed input in changed file">
      grep -Pni 'raise\s+['"'"'"].*malformed' {{file_path}} &amp;&amp; exit 1 || exit 0
    </command>
    <command description="Run specs for the changed file">
      bundle exec rspec {{spec_path}}
    </command>
    <command description="RuboCop passes for changed file">
      bundle exec rubocop {{file_path}}
    </command>
  </verify>

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

  <anti_pattern_sources>
    <source name="IVC CHAMPVA Late Validation" file="modules/ivc_champva/app/controllers/ivc_champva/v1/uploads_controller.rb:853-858" url="https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/modules/ivc_champva/app/controllers/ivc_champva/v1/uploads_controller.rb#L853-L858" />
  </anti_pattern_sources>

</agent_play>
-->

# Validate before you fail (fail early, not late)

This play ensures all input validation happens at the controller boundary before any state changes, using typed exceptions that return correct HTTP status codes.

> [!CAUTION]
> Late validation wastes resources (file uploads, API calls, DB writes) before discovering invalid input.

## Why It Matters

When you defer validation to a helper method called after state mutation, a 50MB file upload completes before discovering an invalid `form_number`, wasting bandwidth, storage, and time. When you use `raise 'Missing param'` (an untyped string raise), Rails wraps it in a `RuntimeError` and returns 500, making the client think the server crashed when the actual problem is a missing parameter that should return 400. Your team then investigates a false "server error" alert while the client retries a request that will never succeed. Failing late costs resources and requires manual rollback of mutated state, while failing early costs only milliseconds.

## Guidance

Validate all inputs at the very start of the controller action -- before any file uploads, database writes, or API calls. Use typed exceptions (`ParameterMissing`, `UnprocessableEntity`) so Rails maps them to the correct 4xx status code automatically. Rails strong parameters and `before_action` callbacks are the preferred mechanisms for boundary validation.

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

### Anti-Patterns from vets-api

#### IVC CHAMPVA Late Validation

##### Anti-Pattern

[modules/ivc_champva/app/controllers/ivc_champva/v1/uploads_controller.rb:853-858](https://github.com/department-of-veterans-affairs/vets-api/blob/b2372803fded80b411dca317dbb94a72536b1f52/modules/ivc_champva/app/controllers/ivc_champva/v1/uploads_controller.rb#L853-L858)

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

##### Impact

Without early validation:

- File uploads complete before realizing `form_number` is invalid (wasted bandwidth, storage)
- Untyped `raise 'string'` returns 500 instead of 422 (misleads client that server crashed)
- Late validation called deep in helper method instead of controller boundary
- Rollback required for partial work (cleanup, orphaned files)

With early validation:

- Invalid `form_number` rejected in <1ms before any file processing starts
- Typed exception returns 422 with actionable error code
- Client gets instant feedback instead of waiting for upload to fail
- No cleanup needed (nothing mutated before validation)

## References

- [Rails Strong Parameters](https://guides.rubyonrails.org/action_controller_overview.html#strong-parameters)
