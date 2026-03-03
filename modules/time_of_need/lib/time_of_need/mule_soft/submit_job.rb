# frozen_string_literal: true

require 'time_of_need/monitor'

module TimeOfNeed
  module MuleSoft
    ##
    # Sidekiq job to submit Time of Need claims to the MuleSoft API.
    #
    # This job takes a saved claim, builds a payload, and POSTs it
    # to the MuleSoft endpoint that routes to MDW → CaMEO (Salesforce).
    #
    # Currently a skeleton — the actual MuleSoft client will be built
    # once we have the endpoint URL, payload schema, and OAuth2 credentials.
    #
    # @example
    #   TimeOfNeed::MuleSoft::SubmitJob.perform_async(claim.id)
    #
    class SubmitJob
      include Sidekiq::Job

      # Generic job error
      class SubmitError < StandardError; end

      # retry for ~2 days (16 retries with exponential backoff)
      sidekiq_options retry: 16, queue: 'low'

      sidekiq_retries_exhausted do |msg|
        begin
          claim = TimeOfNeed::SavedClaim.find(msg['args'].first)
        rescue
          claim = nil
        end
        monitor = TimeOfNeed::Monitor.new
        monitor.track_submission_exhaustion(msg, claim)
      end

      ##
      # Submit a saved claim to MuleSoft
      #
      # @param saved_claim_id [Integer] the claim ID
      # @return [void]
      def perform(saved_claim_id)
        @claim = TimeOfNeed::SavedClaim.find(saved_claim_id)
        raise SubmitError, "Unable to find TimeOfNeed::SavedClaim #{saved_claim_id}" unless @claim

        # TODO: Build payload from @claim.parsed_form
        # TODO: POST payload to MuleSoft client
        # TODO: Handle response, track success/failure
        #
        # Example (once MuleSoft client is built):
        #
        #   payload = build_payload(@claim)
        #   client = TimeOfNeed::MuleSoft::Client.new
        #   response = client.submit(payload)
        #   monitor.track_submission_success(@claim, response)
        #
        Rails.logger.info("[TimeOfNeed] MuleSoft submission not yet implemented for claim #{saved_claim_id}")
      end

      private

      def monitor
        @monitor ||= TimeOfNeed::Monitor.new
      end
    end
  end
end
