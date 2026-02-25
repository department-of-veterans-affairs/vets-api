# frozen_string_literal: true

module RuboCop
  module Cop
    module Sre
      # Play 03 - No bare rescues or rescue Exception.
      #
      # `rescue => e` catches StandardError (too broad).
      # `rescue Exception` catches everything including SignalException and SystemExit.
      # Both hide the real error class and make debugging harder.
      #
      # @example
      #   # bad
      #   rescue => e
      #   rescue Exception => e
      #
      #   # good
      #   rescue Common::Exceptions::BackendServiceException => e
      #   rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
      class NoBareRescues < Base
        MSG_BARE = '[Play 03] Bare `rescue => e` catches all StandardError. ' \
                   'Rescue specific exception classes.'
        MSG_EXCEPTION = '[Play 03] `rescue Exception` catches SignalException and SystemExit. ' \
                        'Rescue specific exception classes.'

        def on_resbody(node)
          exception_classes = node.children[0]

          if exception_classes.nil?
            add_offense(node, message: MSG_BARE)
          elsif rescues_exception?(exception_classes)
            add_offense(node, message: MSG_EXCEPTION)
          end
        end

        private

        def rescues_exception?(exception_node)
          if exception_node.array_type?
            exception_node.children.any? { |child| exception_const?(child) }
          else
            exception_const?(exception_node)
          end
        end

        def exception_const?(node)
          return false unless node.const_type?

          # Match bare `Exception` (no namespace prefix)
          node.children[0].nil? && node.children[1] == :Exception
        end
      end
    end
  end
end
