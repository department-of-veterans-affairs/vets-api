# frozen_string_literal: true

module RuboCop
  module Cop
    module Sre
      # Play 20 - No manual backtrace joining.
      #
      # `e.backtrace.join("\n")` produces unstructured multi-line strings that
      # break log aggregation. Let the logging infrastructure or error tracker
      # handle backtrace formatting.
      #
      # @example
      #   # bad
      #   e.backtrace.join("\n")
      #   error.backtrace.join(', ')
      #
      #   # good
      #   Rails.logger.error(e.message, backtrace: e.backtrace)
      #   # Let Sentry/Datadog handle backtrace formatting
      class NoManualBacktraceJoin < Base
        MSG = '[Play 20] `e.backtrace.join(...)` breaks log aggregation. ' \
              'Pass the backtrace array to structured logging or let the error tracker handle it.'

        # Matches: anything.backtrace.join(...) with any arguments
        def_node_matcher :backtrace_join?, <<~PATTERN
          (send (send _ :backtrace) :join ...)
        PATTERN

        def on_send(node)
          return unless backtrace_join?(node)

          add_offense(node)
        end
      end
    end
  end
end
