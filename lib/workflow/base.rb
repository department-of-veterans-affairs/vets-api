# frozen_string_literal: true

# Ensure Workflow::Runner is deterministically loaded. For details, see:
#   https://github.com/department-of-veterans-affairs/vets.gov-team/issues/4440
#   https://github.com/department-of-veterans-affairs/vets-api/pull/1348
require_dependency 'workflow/runner'

module Workflow
  class Base
    # For subclasses, store the list of Tasks to run in the order defined
    class << self
      attr_accessor :chain
      def run(task, **args)
        @chain ||= []
        @chain << { mod: task, args: args }
      end
    end

    def start!(trace: nil)
      # Queue the first Task with our options.
      trace ||= SecureRandom.uuid
      Workflow::Runner.perform_async(0,
                                     internal: @internal_options.merge(trace: trace),
                                     options: @options)
    end

    # Setup internal bookkeeping
    def initialize(**options)
      @options = options || {}
      @internal_options ||= { chain: chain }
    end

    private

    def chain
      self.class.chain
    end
  end
end
