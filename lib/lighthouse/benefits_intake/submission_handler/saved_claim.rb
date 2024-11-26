# frozen_string_literal: true

require 'zero_silent_failures/monitor'

module BenefitsIntake
  module SubmissionHandler
    class SavedClaim
      def initialize(saved_claim_id)
        @claim = claim_class.find(saved_claim_id)
        @context = {
          form_id: claim.form_id,
          claim_id: claim.id
        }
      end

      def handle(result, call_location: nil, **additional_context)
        @call_location = call_location
        @additional_context = context.merge(additional_context)

        case result
        when 'failure'
          on_failure
        when 'success'
          on_success
        when 'stale'
          on_stale
        end
      end

      private

      attr_reader :additional_context, :call_location, :claim, :context

      def claim_class
        ::SavedClaim
      end

      def monitor
        @monitor ||= ZeroSilentFailures::Monitor.new('benefits-intake')
      end

      def notification_email
        nil
      end

      def on_failure
        if notification_email
          notification_email.deliver(:error)
        elsif claim.respond_to?('send_failure_email')
          claim.send_failure_email
        end

        monitor.log_silent_failure_avoided(additional_context, nil, call_location:)
      rescue => e
        @additional_context = context.merge({ message: e.message })
        monitor.log_silent_failure(additional_context, nil, call_location:)
        raise e
      end

      def on_success
        true
      end

      def on_stale
        true
      end
    end
  end
end
