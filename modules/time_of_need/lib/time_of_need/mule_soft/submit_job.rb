# frozen_string_literal: true

require 'time_of_need/monitor'
require 'time_of_need/mule_soft/payload_builder'
require 'time_of_need/mule_soft/client'

module TimeOfNeed
  module MuleSoft
    ##
    # Sidekiq job to submit Time of Need claims to the MuleSoft API.
    #
    # This job takes a saved claim, builds a structured payload using
    # PayloadBuilder, and POSTs it to the MuleSoft endpoint that routes
    # to MDW → CaMEO (Salesforce).
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

        monitor.track_submission_attempt(@claim)

        payload = build_payload(@claim)
        response = submit_to_mulesoft(payload)

        monitor.track_submission_success(@claim, response)

        Rails.logger.info("[TimeOfNeed] MuleSoft submission succeeded for claim #{saved_claim_id}")
      rescue => e
        monitor.track_submission_failure(@claim, e)
        raise e
      end

      private

      ##
      # Build the structured payload from the saved claim
      #
      # @param claim [TimeOfNeed::SavedClaim]
      # @return [Hash]
      def build_payload(claim)
        TimeOfNeed::MuleSoft::PayloadBuilder.new(claim).build
      end

      ##
      # POST the payload to MuleSoft
      #
      # @param payload [Hash]
      # @return [Hash] parsed response
      def submit_to_mulesoft(payload)
        client = TimeOfNeed::MuleSoft::Client.new
        client.submit(payload)
      end

      def monitor
        @monitor ||= TimeOfNeed::Monitor.new
      end
    end
  end
end
