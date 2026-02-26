---
id: dont-build-module-frameworks
title: Don't build module-specific error handling/logging frameworks
severity: CRITICAL
---

<!--
<agent_play>

  <context>
    The codebase contains 24 custom error-handling frameworks with 24
    different APIs, so a single bug fix must be applied 24 separate
    times. When a LogService catches an exception and never re-raises,
    the span stays open, creating a memory leak that corrupts APM timing
    and hides infrastructure bugs. All 24 frameworks call set_error for
    every exception, marking 4xx client errors as APM errors and
    flooding dashboards with the same misclassification in 24 places. A
    new engineer learns the LogService API, then moves to claims_api and
    encounters a completely different LighthouseErrorHandler API,
    multiplying onboarding friction.
  </context>

  <applies_to>
    <glob>modules/*/app/services/**/*.rb</glob>
    <glob>modules/*/lib/**/*.rb</glob>
    <glob>modules/*/app/controllers/**/*.rb</glob>
  </applies_to>

  <related_plays>
    <play id="expected-vs-unexpected" relationship="complementary" />
    <play id="standardized-error-responses" relationship="complementary" />
  </related_plays>

  <rules>
    <rule enforcement="must_not">
      Do NOT create module-specific error handlers, logging
      services, monitoring classes, or tracing wrappers.
    </rule>
    <rule enforcement="must">
      Use the ExceptionHandling concern for error handling -- let
      exceptions bubble up through the centralized handler.
    </rule>
    <rule enforcement="must">
      Propose requirements for centralized framework to platform
      team rather than building module-specific solutions.
    </rule>
    <rule enforcement="must_not">
      Never wrap Datadog::Tracing, Rails.logger, or StatsD in
      module-specific custom classes -- this fragments the API and
      introduces infrastructure bugs.
    </rule>
    <rule enforcement="must_not">
      Never build module-specific rescue_from handlers -- this
      bypasses ExceptionHandling concern.
    </rule>
    <rule enforcement="should">
      Use standard Rails/Datadog APIs directly until the centralized
      observability framework exists.
    </rule>
    <rule enforcement="should">
      Contribute observability requirements to central
      infrastructure so one framework serves all modules.
    </rule>
    <rule enforcement="verify">
      No new custom logging/tracing/monitoring classes in modules
    </rule>
    <rule enforcement="verify">
      All modules use ExceptionHandling concern for errors
    </rule>
    <rule enforcement="verify">
      Bug fixes applied once (centralized), not 24 times
      (fragmented)
    </rule>
    <rule enforcement="verify">
      Consistent API across all modules
    </rule>
  </rules>

  <investigate_before_answering>
    <step>Read the custom framework class fully to understand what it wraps (Datadog tracing, Rails.logger, StatsD, or error handling).</step>
    <step>Identify whether the custom framework contains infrastructure bugs (span leaks from missing re-raise, incorrect span.set_error for all errors, resource leaks from unclosed spans).</step>
    <step>Determine which standard API the custom framework wraps and whether the module can use the standard API directly.</step>
    <step>Check if the custom framework is a Faraday middleware for HTTP client logging (NOT an anti-pattern) or a domain-specific exception class (NOT an anti-pattern) before flagging.</step>
    <step>Verify whether the module's controllers use ExceptionHandling concern or have custom rescue_from handlers that bypass it. Do not flag Faraday middleware, domain exception classes, or module-specific business logic as anti-patterns. Only flag code that creates a new logging/tracing/monitoring/error-handling API that duplicates centralized infrastructure.</step>
  </investigate_before_answering>

  <severity_assessment>
    <critical>new custom LogService, Monitor, or ErrorHandler class created
in a module</critical>
    <critical>custom framework contains span leak (rescue without re-raise
inside tracing block)</critical>
    <critical>custom rescue_from handler in module bypasses
ExceptionHandling concern</critical>
    <high>custom framework calls span.set_error for all errors
regardless of status code</high>
    <high>new module wraps Datadog::Tracing, Rails.logger, or StatsD in
custom class</high>
    <medium>existing monitor class extended with new methods instead of
proposing centralized requirements</medium>
  </severity_assessment>

  <pr_comment_template>
    **Don't build module-specific frameworks** | `CRITICAL`

    `{{file_path}}:{{line_number}}` -- {{one_line_violation_description}}

    **Why this matters:** 24 modules have already built competing
    logging/tracing/error-handling frameworks. Each has a different API, each
    contains potential infrastructure bugs (span leaks, incorrect error tagging),
    and bug fixes must be applied 24 times. The LogService in ask_va_api has a
    span leak because custom frameworks miss subtle infrastructure requirements.

    **The Rule:** Do NOT create module-specific error handlers, logging services,
    monitoring classes, or tracing wrappers. Use standard APIs directly or propose
    requirements for the centralized framework.

    **Suggested fix:**
    ```ruby
    {{suggested_code}}
    ```

    **Verify:**
    - [ ] No new custom logging/tracing/monitoring class in module
    - [ ] Controllers use ExceptionHandling concern (no custom rescue_from)
    - [ ] Standard APIs used directly (Datadog::Tracing, Rails.logger, StatsD)
    - [ ] Exceptions bubble up to ExceptionHandling
    - [ ] No manual span.set_error in module code

    [Play: Don't Build Module-Specific Frameworks](10-dont-build-module-specific-frameworks.md)
  </pr_comment_template>

</agent_play>
-->

### Do

- Let exceptions bubble up through `ExceptionHandling` concern -- no module-level rescue needed
  ```ruby
  # Controller inherits ExceptionHandling automatically
  class MyController < ApplicationController
    def show
      result = MyService.call(params[:id])
      render json: result
      # No rescue needed -- ExceptionHandling handles it
    end
  end
  ```
- Use standard APIs directly: `Datadog::Tracing.trace`, `Rails.logger`, `StatsD`
  ```ruby
  Datadog::Tracing.trace('my_module.operation') do |span|
    span.set_tag('module', 'my_module')
    result = do_work
  end
  ```
- Propose requirements for centralized framework to platform team rather than building module-specific solutions

### Don't

- Create module-specific `LogService`, `Monitor`, or `ErrorHandler` classes
  ```ruby
  # Bad: module-specific wrapper
  class LogService
    def call(action, &block)
      @tracer.trace(action) { |span| block.call(span) }
    rescue => e
      handle_logging_error(action, e, span)
      # Missing: raise -- span leak!
    end
  end
  ```
- Wrap `Datadog::Tracing`, `Rails.logger`, or `StatsD` in module-specific custom classes
- Build module-specific `rescue_from` handlers that bypass `ExceptionHandling`
  ```ruby
  # Bad: bypasses centralized error handling
  class MyModuleController < ApplicationController
    rescue_from StandardError, with: :handle_error

    def handle_error(e)
      render json: { error: e.message }, status: 500
    end
  end
  ```

## Anti-Patterns

### ask_va_api/LogService

```ruby
class LogService
  def call(action, tags: {}, &block)
    span = nil
    trace_and_annotate_action(action, tags) do |s|
      @span = span = s
      if block.arity == 1
        block.call(span)
      else
        @elapsed_time = Benchmark.realtime { @result = block.call }
      end
    end
    log_timing_metric(action)
    result
  rescue => e
    handle_logging_error(action, e, span)  # Bug: Never re-raises exception
    # Missing: raise
  end

  private

  def trace_and_annotate_action(action, tags)
    @tracer.trace(action) do |span|
      set_tags_and_metrics(span, action, tags)
      yield(span) if block_given?
    end  # Span never closes properly if exception caught above
  end

  def handle_logging_error(action, error, span)
    @logger.error("Error logging action #{action}: #{error.message}")
    if span
      span.set_error(error)  # Calls span.set_error for ALL errors (violates playbook)
    end
  end
end
```

```ruby
rescue => e
  handle_logging_error(action, e, span)
  raise  # Re-raise to allow Datadog to close span properly
end
```
