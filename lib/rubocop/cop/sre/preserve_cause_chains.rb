# frozen_string_literal: true

module RuboCop
  module Cop
    module Sre
      # Play 02 - Preserve exception cause chains.
      #
      # Re-raising with `raise "...#{e}..."` or `raise "...#{e.message}..."`
      # inside a rescue block discards the original exception's cause chain
      # and backtrace. Use `raise NewError, "msg"` to let Ruby preserve `.cause`.
      #
      # @example
      #   # bad
      #   rescue SomeError => e
      #     raise "Failed: #{e.message}"
      #
      #   # good
      #   rescue SomeError => e
      #     raise MyError, "Failed: #{e.message}"
      class PreserveCauseChains < Base
        MSG = '[Play 02] `raise "...#{e}..."` inside rescue discards the cause chain. ' \
              'Use `raise TypedError, message` to preserve `.cause`.'

        def on_resbody(node)
          exception_var = node.children[1]
          return unless exception_var

          var_name = exception_var.children[0]

          node.each_descendant(:send) do |send_node|
            next unless send_node.method?(:raise)
            next unless send_node.receiver.nil?
            next unless send_node.arguments.size == 1

            arg = send_node.arguments.first
            next unless arg.dstr_type?
            next unless interpolates_variable?(arg, var_name)

            add_offense(send_node)
          end
        end

        private

        def interpolates_variable?(dstr_node, var_name)
          dstr_node.each_descendant(:lvar, :send).any? do |node|
            if node.lvar_type?
              node.children[0] == var_name
            elsif node.send_type? && node.receiver&.lvar_type?
              node.receiver.children[0] == var_name
            else
              false
            end
          end
        end
      end
    end
  end
end
