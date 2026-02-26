# frozen_string_literal: true

module RuboCop
  module Cop
    module Sre
      # Play 16 - Don't swallow errors silently.
      #
      # A rescue block whose body returns nil, false, an empty array, or an
      # empty hash silently swallows the exception. At minimum, log the error
      # or re-raise it.
      #
      # @example
      #   # bad
      #   rescue => e
      #     nil
      #   rescue SomeError
      #     []
      #   rescue SomeError => e
      #     {}
      #
      #   # good
      #   rescue SomeError => e
      #     Rails.logger.error("something failed", error: e.class.name)
      #     nil
      class DontSwallowErrors < Base
        MSG = '[Play 16] Rescue block returns `%<value>s` — error is silently swallowed. ' \
              'Log the error or re-raise.'

        def on_resbody(node)
          body = node.body
          return unless body

          # If the body contains a raise, it's not swallowing
          return if body.each_node(:send).any? { |n| n.method?(:raise) }
          # If the body contains logging, it's intentional
          return if body.each_node(:send).any? { |n| logger_call?(n) }

          last_expr = last_expression(body)
          swallowed = swallowed_value(last_expr)
          return unless swallowed

          add_offense(node, message: format(MSG, value: swallowed))
        end

        private

        def last_expression(node)
          node.begin_type? || node.kwbegin_type? ? node.children.last : node
        end

        def swallowed_value(node)
          return unless node

          case node.type
          when :nil then 'nil'
          when :false then 'false' # rubocop:disable Lint/BooleanSymbol
          when :array then node.children.empty? ? '[]' : nil
          when :hash then node.children.empty? ? '{}' : nil
          end
        end

        def logger_call?(node)
          return false unless %i[error warn info debug].include?(node.method_name)

          receiver = node.receiver
          return false unless receiver

          # Match logger.error or Rails.logger.error
          if receiver.send_type?
            receiver.method?(:logger)
          else
            false
          end
        end
      end
    end
  end
end
