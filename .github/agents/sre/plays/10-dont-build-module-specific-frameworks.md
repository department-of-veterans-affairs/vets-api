# Play 10: Don't Build Module-Specific Error Handling/Logging Frameworks

## Context
The codebase contains 24 custom error-handling frameworks with 24 different APIs, so a single bug fix must be applied 24 separate times. When a LogService catches an exception and never re-raises, the span stays open, creating a memory leak that corrupts APM timing and hides infrastructure bugs. All 24 frameworks call `set_error` for every exception, marking 4xx client errors as APM errors and flooding dashboards with the same misclassification in 24 places. A new engineer learns the LogService API, then moves to claims_api and encounters a completely different LighthouseErrorHandler API, multiplying onboarding friction.

## Applies To
- `modules/*/app/services/**/*.rb`
- `modules/*/lib/**/*.rb`
- `modules/*/app/controllers/**/*.rb`

## Investigation Steps
1. Read the custom framework class fully to understand what it wraps (Datadog tracing, Rails.logger, StatsD, or error handling).
2. Identify whether the custom framework contains infrastructure bugs (span leaks from missing re-raise, incorrect `span.set_error` for all errors, resource leaks from unclosed spans).
3. Determine which standard API the custom framework wraps and whether the module can use the standard API directly.
4. Check if the custom framework is a Faraday middleware for HTTP client logging (NOT an anti-pattern) or a domain-specific exception class (NOT an anti-pattern) before flagging.
5. Verify whether the module's controllers use ExceptionHandling concern or have custom `rescue_from` handlers that bypass it. Only flag code that creates a new logging/tracing/monitoring/error-handling API that duplicates centralized infrastructure.

## Severity Assessment
- **CRITICAL:** New custom LogService, Monitor, or ErrorHandler class created in a module
- **CRITICAL:** Custom framework contains span leak (rescue without re-raise inside tracing block)
- **CRITICAL:** Custom `rescue_from` handler in module bypasses ExceptionHandling concern
- **HIGH:** Custom framework calls `span.set_error` for all errors regardless of status code
- **HIGH:** New module wraps `Datadog::Tracing`, `Rails.logger`, or `StatsD` in custom class
- **MEDIUM:** Existing monitor class extended with new methods instead of proposing centralized requirements

## Golden Patterns

### Do
Let exceptions bubble up through `ExceptionHandling` concern -- no module-level rescue needed:
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

Use standard APIs directly: `Datadog::Tracing.trace`, `Rails.logger`, `StatsD`:
```ruby
Datadog::Tracing.trace('my_module.operation') do |span|
  span.set_tag('module', 'my_module')
  result = do_work
end
```

Propose requirements for centralized framework to platform team rather than building module-specific solutions.

### Don't
Never create module-specific `LogService`, `Monitor`, or `ErrorHandler` classes:
```ruby
# BAD: module-specific wrapper
class LogService
  def call(action, &block)
    @tracer.trace(action) { |span| block.call(span) }
  rescue => e
    handle_logging_error(action, e, span)
    # Missing: raise -- span leak!
  end
end
```

Never wrap `Datadog::Tracing`, `Rails.logger`, or `StatsD` in module-specific custom classes.

Never build module-specific `rescue_from` handlers that bypass `ExceptionHandling`:
```ruby
# BAD: bypasses centralized error handling
class MyModuleController < ApplicationController
  rescue_from StandardError, with: :handle_error

  def handle_error(e)
    render json: { error: e.message }, status: 500
  end
end
```

## Anti-Patterns

### ask_va_api LogService with Span Leak
**Anti-pattern:**
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

  def handle_logging_error(action, error, span)
    @logger.error("Error logging action #{action}: #{error.message}")
    if span
      span.set_error(error)  # Calls span.set_error for ALL errors
    end
  end
end
```
**Problem:** When an exception is raised inside the block, the `rescue` catches it but never re-raises. The Datadog span remains open, leaking memory and corrupting span timing. Additionally, `span.set_error` is called for ALL errors including expected 4xx. The module-specific API means only ask_va_api uses this -- other modules built different implementations.

**Corrected:**
```ruby
# Use standard APIs directly -- no custom wrapper needed
class MyController < ApplicationController
  def show
    result = MyService.call(params[:id])
    render json: result
    # ExceptionHandling handles errors automatically
  end
end

# If tracing is needed, use Datadog directly
Datadog::Tracing.trace('my_module.operation') do |span|
  span.set_tag('module', 'my_module')
  result = do_work
end
# Datadog closes span automatically, even on exception
```

## Finding Template
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

## Verify Commands
```bash
# No custom LogService classes in modules
grep -rn 'class.*LogService' modules/ --include='*.rb' && exit 1 || exit 0

# No custom ErrorHandler classes in modules
grep -rn 'class.*ErrorHandler' modules/ --include='*.rb' && exit 1 || exit 0

# No custom rescue_from in module controllers
grep -rn 'rescue_from' modules/*/app/controllers/ --include='*.rb' | grep -v '#' && exit 1 || exit 0

# No manual span.set_error in modules
grep -rn 'span.*set_error\|set_error.*span' modules/ --include='*.rb' | grep -v '#' | grep -v spec && exit 1 || exit 0

# Run specs for changed module
bundle exec rspec {{spec_path}}
```

## Related Plays
- Play: Expected vs Unexpected Errors (complementary)
- Play: Standardized Error Responses (complementary)
