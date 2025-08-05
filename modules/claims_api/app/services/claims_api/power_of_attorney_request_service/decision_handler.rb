# frozen_string_literal: true

require_relative 'declined_decision_handler'

module ClaimsApi
  module PowerOfAttorneyRequestService
    class DecisionHandler
      LOG_TAG = 'decision_handler'

      DECISION_HANDLERS = {
        'declined' => ClaimsApi::PowerOfAttorneyRequestService::DeclinedDecisionHandler,
        'accepted' => ClaimsApi::PowerOfAttorneyRequestService::AcceptedDecisionHandler
      }.freeze

      # rubocop:disable Metrics/ParameterLists
      def initialize(decision:, proc_id:, registration_number:, poa_code:, metadata:, veteran:, claimant: nil)
        @decision = decision
        @proc_id = proc_id
        @registration_number = registration_number
        @poa_code = poa_code
        @metadata = metadata
        @veteran = veteran
        @claimant = claimant
      end
      # rubocop:enable Metrics/ParameterLists

      def call
        ClaimsApi::Logger.log(
          LOG_TAG, message: "Starting the #{@decision} POA workflow for procID: #{@proc_id}."
        )
        # accepted/declined are validated by the schema so we can trust it is one or the other here
        handler_class = DECISION_HANDLERS[@decision]

        data, type = make_call_for_decision(handler_class)

        @decision == 'accepted' ? [data, type] : []
      end

      private

      def make_call_for_decision(handler_class)
        if @decision == 'declined'
          handler_class.new(
            ptcpnt_id: @veteran.participant_id,
            proc_id: @proc_id,
            representative_id: @registration_number
          ).call
        end

        if @decision == 'accepted'
          handler_class.new(
            proc_id: @proc_id,
            poa_code: @poa_code,
            registration_number: @registration_number,
            metadata: @metadata,
            veteran: @veteran,
            claimant: @claimant
          ).call
        end
      end
    end
  end
end
