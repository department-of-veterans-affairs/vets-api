# frozen_string_literal: true

module RuboCop
  module Cop
    module Sidekiq
      # Requires that Sidekiq jobs explicitly specify a retry value.
      #
      # Sidekiq defaults to 25 retries if not specified, which may not be
      # appropriate for all jobs. Explicitly setting retry ensures developers
      # have considered the retry behavior for each job.
      #
      # @example
      #   # bad
      #   class MyJob
      #     include Sidekiq::Job
      #     sidekiq_options queue: 'default'
      #   end
      #
      #   # bad - no sidekiq_options at all
      #   class MyJob
      #     include Sidekiq::Job
      #   end
      #
      #   # good
      #   class MyJob
      #     include Sidekiq::Job
      #     sidekiq_options retry: 5
      #   end
      #
      class RequireRetry < RuboCop::Cop::Base
        MSG = 'Sidekiq jobs must explicitly specify `retry` in sidekiq_options'

        # Matches `include Sidekiq::Job` or `include Sidekiq::Worker`
        def_node_matcher :includes_sidekiq?, <<~PATTERN
          (send nil? :include (const (const nil? :Sidekiq) {:Job :Worker}))
        PATTERN

        # Matches sidekiq_options call
        def_node_matcher :sidekiq_options_call?, <<~PATTERN
          (send nil? :sidekiq_options ...)
        PATTERN

        def on_class(node)
          return unless sidekiq_class?(node)
          return if retry_option?(node)

          # Report on the class definition line
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

        def retry_option?(node)
          return false unless node.body

          node.body.each_descendant(:send).any? do |send_node|
            next unless sidekiq_options_call?(send_node)

            retry_key?(send_node)
          end
        end

        def retry_key?(send_node)
          send_node.arguments.any? do |arg|
            next unless %i[kwargs hash].include?(arg.type)

            arg.pairs.any? { |pair| pair.key.value == :retry }
          end
        end
      end
    end
  end
end
