# frozen_string_literal: true

module RuboCop
  module Cop
    module Sidekiq
      # Requires that Sidekiq jobs implement `sidekiq_retries_exhausted` hook.
      #
      # Jobs should handle retry exhaustion explicitly rather than relying on
      # Sidekiq's global death_handlers or the Dead Queue. This ensures failures
      # are handled appropriately with options like alternate resubmission paths
      # or escalation through alerts.
      #
      # Exception: Jobs that have disabled retries (retry: 0) are exempt if all
      # exceptions are caught and handled in the perform() method.
      #
      # @example
      #   # bad
      #   class MyJob
      #     include Sidekiq::Job
      #     sidekiq_options retry: 5
      #   end
      #
      #   # good
      #   class MyJob
      #     include Sidekiq::Job
      #     sidekiq_options retry: 5
      #
      #     sidekiq_retries_exhausted do |msg, ex|
      #       # handle exhaustion
      #     end
      #   end
      #
      #   # good - no retries, so no exhausted hook needed
      #   class MyJob
      #     include Sidekiq::Job
      #     sidekiq_options retry: 0
      #   end
      #
      class RequireExhaustedHook < RuboCop::Cop::Base
        MSG = 'Sidekiq jobs with retries must implement `sidekiq_retries_exhausted` hook'

        # Matches `include Sidekiq::Job` or `include Sidekiq::Worker`
        def_node_matcher :includes_sidekiq?, <<~PATTERN
          (send nil? :include (const (const nil? :Sidekiq) {:Job :Worker}))
        PATTERN

        # Matches sidekiq_options call
        def_node_matcher :sidekiq_options_call?, <<~PATTERN
          (send nil? :sidekiq_options ...)
        PATTERN

        # Matches sidekiq_retries_exhausted block
        def_node_matcher :retries_exhausted_block?, <<~PATTERN
          (block (send nil? :sidekiq_retries_exhausted) ...)
        PATTERN

        def on_class(node)
          return unless sidekiq_class?(node)
          return if retries_disabled?(node)
          return if exhausted_hook?(node)

          add_offense(node.loc.name)
        end

        private

        def sidekiq_class?(node)
          return false unless node.body

          if node.body.type == :send
            includes_sidekiq?(node.body)
          else
            node.body.each_descendant(:send).any? { |send_node| includes_sidekiq?(send_node) }
          end
        end

        def retries_disabled?(node)
          return false unless node.body

          node.body.each_descendant(:send).any? do |send_node|
            next unless sidekiq_options_call?(send_node)

            retry_value = get_retry_value(send_node)
            [0, false].include?(retry_value)
          end
        end

        def get_retry_value(send_node)
          send_node.arguments.each do |arg|
            next unless %i[kwargs hash].include?(arg.type)

            arg.pairs.each do |pair|
              next unless pair.key.value == :retry

              value_node = pair.value

              return value_node.value if value_node.int_type?
              return false if value_node.false_type?
              return true if value_node.true_type?
            end
          end
          nil
        end

        def exhausted_hook?(node)
          return false unless node.body

          node.body.each_descendant(:block).any? { |block_node| retries_exhausted_block?(block_node) }
        end
      end
    end
  end
end
