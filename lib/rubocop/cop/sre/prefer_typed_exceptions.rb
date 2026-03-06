# frozen_string_literal: true

module RuboCop
  module Cop
    module Sre
      # Play 08 - Prefer typed exception classes over bare string raises.
      #
      # `raise "message"` creates a RuntimeError which maps to a generic 500.
      # Use a specific exception class so upstream callers can rescue selectively.
      #
      # @example
      #   # bad
      #   raise "something went wrong"
      #   raise "failed: #{detail}"
      #
      #   # good
      #   raise MyApp::SomeError, "something went wrong"
      #   raise Common::Exceptions::BackendServiceException
      class PreferTypedExceptions < Base
        MSG = '[Play 08] `raise "message"` creates RuntimeError (500). ' \
              'Use a typed exception class.'

        # Matches: raise 'string' or raise "string with #{interpolation}"
        # Does NOT match: raise SomeError, "message" (has a const receiver)
        def_node_matcher :raise_with_string?, <<~PATTERN
          (send nil? :raise {(str _) (dstr ...)})
        PATTERN

        def on_send(node)
          return unless raise_with_string?(node)

          add_offense(node)
        end
      end
    end
  end
end
