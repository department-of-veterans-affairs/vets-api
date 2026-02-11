---
id: dont-build-module-frameworks
title: Don't build module-specific error handling/logging frameworks
version: 1
severity: CRITICAL
category: exception-handling
tags:
- fragmentation
- custom-framework
- centralized-handling
- span-leak
- module-specific
language: ruby
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

  <retrieval_triggers>
    <trigger>custom LogService or Monitor class in module</trigger>
    <trigger>module-specific error handler bypasses ExceptionHandling</trigger>
    <trigger>span leak from custom tracing wrapper</trigger>
    <trigger>24 different error handling frameworks across modules</trigger>
    <trigger>custom rescue_from handler in module controller</trigger>
    <trigger>building module-specific logging or monitoring class</trigger>
  </retrieval_triggers>

  <detection>
    <pattern name="custom_log_service_class" confidence="high">
      <signature>class\s+\w*LogService</signature>
      <description>
        Defines a custom logging service class in a module. Module-
        specific logging services wrap Datadog tracing, Rails.logger,
        or StatsD in custom APIs, fragmenting observability across
        modules and introducing infrastructure bugs like span leaks.
      </description>
      <example>class LogService</example>
      <example>class AskVaLogService</example>
    </pattern>
    <pattern name="custom_monitor_class" confidence="medium">
      <signature>class\s+\w*Monitor\b</signature>
      <description>
        Defines a custom monitor class in a module. These typically
        wrap StatsD or Datadog tracing with module-specific APIs.
        Medium confidence because some monitor classes may extend
        BaseMonitor legitimately -- check whether the class creates a
        new tracing/logging API or simply tracks domain metrics.
      </description>
      <example>class Monitor &lt; BaseMonitor</example>
      <example>class DependentsBenefitsMonitor</example>
    </pattern>
    <pattern name="custom_error_handler_class" confidence="high">
      <signature>class\s+\w*ErrorHandler</signature>
      <description>
        Defines a custom error handler class in a module. These bypass
        the ExceptionHandling concern by implementing module-specific
        rescue_from handlers, creating inconsistent error rendering
        and APM tagging behavior across modules.
      </description>
      <example>class ErrorHandler</example>
      <example>class LighthouseErrorHandler</example>
      <example>class SoapErrorHandler</example>
    </pattern>
    <pattern name="custom_rescue_from_in_module" confidence="high">
      <signature>def\s+rescue_from</signature>
      <description>
        Defines a custom rescue_from handler inside a module
        controller or concern. Module-specific rescue_from handlers
        bypass the centralized ExceptionHandling concern, creating
        inconsistent error rendering, logging, and APM behavior.
      </description>
      <example>def rescue_from(exception)` in a module controller</example>
      <example>rescue_from StandardError, with: :handle_error` in module base controller</example>
    </pattern>
    <heuristic>
      A module that defines its own class wrapping
      `Datadog::Tracing.trace`, `Rails.logger`, or `StatsD` is
      creating a module-specific observability framework. The class
      name often includes "Log", "Monitor", "Trace", or "Metric" --
      any of these in `modules/*/` are strong signals of framework
      fragmentation.
    </heuristic>
    <heuristic>
      A module controller that defines its own `rescue_from` handler
      or overrides error rendering instead of relying on the
      inherited ExceptionHandling concern is bypassing centralized
      error handling. Check whether the module's
      ApplicationController or base controller includes custom error
      handling logic.
    </heuristic>
    <false_positive>
      Faraday middleware for HTTP client logging (e.g.,
      `vaos/middleware/vaos_logging.rb`) is NOT an anti-pattern.
      This logs outbound HTTP calls at the middleware layer, which
      is appropriate and does not create a module-specific
      observability framework.
    </false_positive>
    <false_positive>
      Domain-specific exception classes (e.g.,
      `ClaimsApi::PowerOfAttorneyNotFound`) are NOT anti-patterns.
      These are business exceptions that map to specific HTTP status
      codes and flow through ExceptionHandling normally.
    </false_positive>
    <false_positive>
      Module-specific business logic that happens to include logging
      (e.g., JWT jti extraction for audit) is NOT an anti-pattern.
      The test is whether the code creates a new
      logging/tracing/monitoring API or simply uses standard
      Rails/Datadog APIs for a domain-specific purpose.
    </false_positive>
  </detection>

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

  <default_to_action>
    When you detect a new custom logging/tracing/error-handling
    framework being created in a module, compose a PR comment that
    includes: 1. The specific violation (new custom framework in
    module) 2. The fragmentation context (24 existing custom
    frameworks, each with different APIs and potential
    infrastructure bugs) 3. The span leak example from LogService
    as evidence of why custom frameworks are dangerous 4. A
    concrete suggestion to use standard APIs directly
    (Datadog::Tracing, Rails.logger, StatsD) or propose
    requirements to the platform team 5. A link to this play Do
    not simply flag the violation -- explain why 24 custom
    frameworks is worse than 1 centralized framework, and provide
    the standard API alternative.
  </default_to_action>

  <verify>
    <command description="No custom LogService classes in modules">
      grep -rn 'class.*LogService' modules/ --include='*.rb' &amp;&amp; exit 1 || exit 0
    </command>
    <command description="No custom ErrorHandler classes in modules">
      grep -rn 'class.*ErrorHandler' modules/ --include='*.rb' &amp;&amp; exit 1 || exit 0
    </command>
    <command description="No custom rescue_from in module controllers">
      grep -rn 'rescue_from' modules/*/app/controllers/ --include='*.rb' | grep -v '#' &amp;&amp; exit 1 || exit 0
    </command>
    <command description="No manual span.set_error in modules">
      grep -rn 'span.*set_error\|set_error.*span' modules/ --include='*.rb' | grep -v '#' | grep -v spec &amp;&amp; exit 1 || exit 0
    </command>
    <command description="Run specs for changed module">
      bundle exec rspec {{spec_path}}
    </command>
  </verify>

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

    [Play: Don't Build Module-Specific Frameworks](plays/dont-build-module-specific-frameworks.md)
  </pr_comment_template>

  <anti_pattern_sources>
    <source name="ask_va_api LogService with span leak" file="modules/ask_va_api/app/services/log_service.rb" url="https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/ask_va_api/app/services/log_service.rb" />
  </anti_pattern_sources>

</agent_play>
-->

# Don't build module-specific error handling/logging frameworks

Every module-specific logging service, error handler, or tracing wrapper fragments the codebase and introduces infrastructure bugs that must be found and fixed independently across dozens of implementations.

> [!CAUTION]
> Custom frameworks introduce span leaks, incorrect error tagging, and memory corruption that hide behind module-specific APIs where platform engineers cannot find or fix them.

## Why It Matters

When you build a custom LogService or ErrorHandler in your module, you are adding to a collection of 24 competing frameworks -- each with a different API, each containing potential infrastructure bugs like span leaks and incorrect error classification. When the platform team fixes a span lifecycle bug, that fix must be applied 24 separate times instead of once. Your new engineer learns your module's `LogService.call()` API, then moves to claims_api and encounters a completely different `LighthouseErrorHandler` API, multiplying onboarding friction. Custom frameworks that catch exceptions without re-raising leave Datadog spans open, leaking memory and corrupting APM timing data across your entire module.

## Guidance

Use the existing `ExceptionHandling` concern for error handling and standard Rails/Datadog APIs directly for logging and tracing. If you need capabilities that do not exist yet (service-scoped tracing, automatic benchmarking, structured logging with context), propose those requirements to the platform team so one centralized framework can serve all modules.

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

**Source:** [modules/ask_va_api/app/services/log_service.rb](https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/ask_va_api/app/services/log_service.rb)

This custom logging service wraps Datadog tracing and Rails logging. It was created to provide:

- Automatic benchmarking (**valid requirement**)
- Automatic timing metrics (**valid requirement**)
- Module-specific API (**wrong approach**)

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

**Critical Bug: Span Leak** (lines 28-30)

When an exception is raised inside the block (line 19 or 21):

1. The `rescue => e` catches it (line 28)
2. `handle_logging_error` is called (line 29)
3. **Exception is never re-raised** (missing `raise` on line 30)
4. Method returns normally, but the `@tracer.trace` block (line 35) never completed properly
5. **Datadog span remains open**, leaking memory and corrupting span timing

**Correct behavior**: Must re-raise after logging:

```ruby
rescue => e
  handle_logging_error(action, e, span)
  raise  # Re-raise to allow Datadog to close span properly
end
```

**Why this bug exists**: Infrastructure code (span lifecycle management) requires deep expertise. Teams building custom frameworks often miss subtle but critical requirements like "always close spans, even on error."

**Additional Problems**:

1. **Violates "expected errors" play**: Calls `span.set_error` for ALL errors including 4xx (line 57)
2. **Bypasses ExceptionHandling**: Exceptions should flow through ExceptionHandling for centralized handling
3. **Module-specific API**: Only ask_va_api can use this -- other 23 modules built different implementations
4. **Maintenance burden**: When fixing bugs (like span leak or `span.set_error` issue), must update LogService + ExceptionHandling + 22 other frameworks

## Reference

### Why This Happens

Teams build custom frameworks thinking they're "adding value" with convenience methods or module-specific logging. The intentions are good:

- "We need service-scoped tracing" -- **Valid requirement**
- "We need automatic benchmarking" -- **Valid requirement**
- "We need module-specific metrics" -- **Valid requirement**
- "We need structured logging with context" -- **Valid requirement**

**But the approach is wrong**: Building 24 separate implementations fragments the system **and introduces bugs**.

**The right approach**: Build **ONE centralized framework** (TBD) that handles these requirements for all modules.

### The Fragmentation Crisis

**Current state**: 24+ custom implementations found across modules

#### Category 1: Custom Tracing/Logging Services (2 implementations)

1. [ask_va_api/app/services/log_service.rb](https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/ask_va_api/app/services/log_service.rb) -- Custom Datadog tracing wrapper with benchmarking
2. [accredited_representative_portal/app/services/accredited_representative_portal/monitoring.rb](https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/accredited_representative_portal/app/services/accredited_representative_portal/monitoring.rb) -- Custom tracing + StatsD wrapper

#### Category 2: Custom Error Handlers (5 implementations)

3. [claims_api/lib/claims_api/error/error_handler.rb](https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/claims_api/lib/claims_api/error/error_handler.rb) -- Custom `rescue_from` with simplified rendering
4. [claims_api/lib/claims_api/v2/error/lighthouse_error_handler.rb](https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/claims_api/lib/claims_api/v2/error/lighthouse_error_handler.rb) -- Extended error handler with backtrace source tracking
5. [claims_api/lib/claims_api/error/soap_error_handler.rb](https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/claims_api/lib/claims_api/error/soap_error_handler.rb) -- SOAP-specific error handler
6. [ask_va_api/app/services/error_handler.rb](https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/ask_va_api/app/services/error_handler.rb) -- Module error handler
7. [ask_va_api/app/services/crm/error_handler.rb](https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/ask_va_api/app/services/crm/error_handler.rb) -- Sub-module error handler

#### Category 3: Custom Monitor Classes (14 implementations extending BaseMonitor)

8-21. Various module-specific monitor classes in dependents_benefits, increase_compensation, medical_expense_reports, claims_evidence_api, vre, dependents_verification, accredited_representative_portal, decision_reviews, bpds, pensions, burials, ivc_champva, income_and_assets

#### Category 4: Custom Logging Utilities (2 implementations)

22. [decision_reviews/lib/decision_reviews/v1/logging_utils.rb](https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/decision_reviews/lib/decision_reviews/v1/logging_utils.rb) -- `log_formatted` with 8-parameter interface
23. [vaos/app/services/vaos/middleware/vaos_logging.rb](https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/vaos/app/services/vaos/middleware/vaos_logging.rb) -- Faraday middleware (**NOT an anti-pattern** -- this is appropriate for HTTP client logging)

#### Category 5: Custom Application Controllers (2 implementations)

24. [ask_va_api/app/controllers/ask_va_api/application_controller.rb](https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/ask_va_api/app/controllers/ask_va_api/application_controller.rb#L54-L59) -- `log_error` method with manual `span.set_error`
25. [mobile/app/controllers/mobile/concerns/sso_logging.rb](https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/mobile/app/controllers/mobile/concerns/sso_logging.rb) -- Custom SSO logging

### Impact of Fragmentation

**Current state** (24 custom frameworks):

- **24 different APIs**: `LogService.call()` vs `Monitoring.trace()` vs `Monitor.track_submission_success()` vs `log_formatted()`
- **Bug fixes require 24 updates**: The span leak bug above exists in LogService. Similar bugs likely exist in other 23 frameworks. Each must be found and fixed independently.
- **Infrastructure bugs multiply**: Custom frameworks contain subtle bugs (span leaks, incorrect error tagging, resource leaks, memory leaks, timing errors)
- **Playbook violations multiply**: The `span.set_error` fix must be applied to ExceptionHandling + 24 custom frameworks
- **Onboarding friction**: "Why does ask_va use LogService but claims_api uses LighthouseErrorHandler?"
- **Inconsistent behavior**: Some modules call `span.set_error` for 4xx, some don't

**Desired state** (ONE centralized framework - TBD):

- **One API**: All modules use centralized observability framework
- **One place for bug fixes**: Fix span leak in centralized framework -> All modules fixed
- **Infrastructure expertise centralized**: Platform team maintains span lifecycle, error classification, resource cleanup
- **Playbook rules enforced automatically**: Centralized framework checks `status_code >= 500` before calling `span.set_error`
- **Consistent behavior**: All modules follow playbook rules automatically
- **Shared features**: All modules get benchmarking, structured logging, duration tracking, etc.
- **Easy onboarding**: Learn one API, use across all modules

### When Custom Code IS Appropriate

**These are NOT anti-patterns**:

- **Faraday middleware for HTTP client logging** (e.g., [vaos/middleware/vaos_logging.rb](https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/vaos/app/services/vaos/middleware/vaos_logging.rb)) -- logs outbound HTTP calls, appropriate
- **Domain-specific exception classes** (e.g., `ClaimsApi::PowerOfAttorneyNotFound`) -- business exceptions, appropriate
- **Module-specific business logic** (e.g., JWT jti extraction for audit) -- domain requirement, appropriate

**What IS an anti-pattern**:

- **Wrapping Datadog::Tracing, Rails.logger, or StatsD** -- creates module-specific API and introduces infrastructure bugs
- **Building module-specific `rescue_from` handlers** -- bypasses ExceptionHandling concern
- **Creating Monitor classes that wrap StatsD** -- duplicates infrastructure, introduces bugs

## References

- [ExceptionHandling concern](https://github.com/department-of-veterans-affairs/vets-api/blob/master/app/controllers/concerns/exception_handling.rb)
