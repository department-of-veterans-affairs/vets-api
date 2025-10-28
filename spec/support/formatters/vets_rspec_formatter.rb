
require 'rspec/core/formatters'

# Example output of formatter
# ClaimsApi::CustomError
# .
# correctly sets the key as the string value from the error message (FAILED - 1)
# ........


class VetsRspecFormatter < RSpec::Core::Formatters::DocumentationFormatter
  RSpec::Core::Formatters.register self,
    :example_group_started,
    :example_passed,
    :example_failed,
    :example_pending

  # only output the top describe group
  def example_group_started(notification)
    @output.puts "\n#{notification.group.description.strip}\n" if @group_level == 0
    @group_level += 1
  end

   # dots for passing like progress
  def example_passed(passed)
    @output.print '.'

    flush_messages
    @example_running = false
  end

  # failure message like documentation
  def example_failed(failure)
    failure_message = failure_output(failure.example)
    output.puts "\n#{failure_message}\n"

    flush_messages
    @example_running = false
  end

  # asterisk for pending like progress
  def example_pending(_notification)
    @output.print '*'
  end

  private

  def failure_output(example)
    RSpec::Core::Formatters::ConsoleCodes.wrap("#{example.description.strip} " \
                      "(FAILED - #{next_failure_index})",
                      :failure)
  end
end
