# frozen_string_literal: true

require_relative 'declined_decision_handler'

module ClaimsApi
  module PowerOfAttorneyRequestService
    class DecisionHandler
      DECISION_HANDLERS = {
        'declined' => ClaimsApi::PowerOfAttorneyRequestService::DeclinedDecisionHandler,
        'accepted' => ClaimsApi::PowerOfAttorneyRequestService::AcceptedDecisionHandler
      }.freeze

      # rubocop:disable Metrics/ParameterLists
      def initialize(decision:, ptcpnt_id:, proc_id:, representative_id:, poa_code:, metadata:, claimant_ptcpnt_id:)
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
        handler_class = DECISION_HANDLERS[@decision]
        return unless handler_class

        make_call_for_decision(handler_class)
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
