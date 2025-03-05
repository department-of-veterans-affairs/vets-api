# frozen_string_literal: true

require 'zero_silent_failures/monitor'

module BenefitsIntake
  module SubmissionHandler
    class SavedClaim
      # constructor
      # @param saved_claim_id [Integer] the database id of the claim
      def initialize(saved_claim_id)
        @claim = claim_class.find(saved_claim_id)
        @context = {
          form_id: claim.form_id,
          claim_id: claim.id
        }
      end

      # respond to result of a submission status
      #
      # @param result [String] the resulting state of a submission
      # @param call_location [CallLocation] where the result is being determined
      # @param **additional_context [Mixed] additional information to be logged
      def handle(result, call_location: nil, **additional_context)
        @call_location = call_location
        @additional_context = context.merge(additional_context)

        case result.to_s
        when 'failure'
          on_failure
        when 'success'
          on_success
        when 'stale'
          on_stale
        end
      end

      private

      attr_reader :additional_context, :avoided, :call_location, :claim, :context

      # the type of SavedClaim to be queried
      def claim_class
        ::SavedClaim
      end

      # the monitor to be used
      # @see ZeroSilentFailures::Monitor
      def monitor
        @monitor ||= ZeroSilentFailures::Monitor.new('lighthouse-benefits-intake')
      end

      # handle a failure result
      # inheriting class must assign @avoided before calling `super`
      def on_failure
        raise "#{self.class}: on_failure silent failure not avoided" unless avoided

        monitor.log_silent_failure_avoided(additional_context, call_location:)
      rescue => e
        @additional_context = additional_context.merge({ message: e.message })
        monitor.log_silent_failure(additional_context, call_location:)
        raise e
      end

      # handle a success result
      def on_success
        true
      end

      # handle a stale result
      def on_stale
        true
      end
    end
  end
end
