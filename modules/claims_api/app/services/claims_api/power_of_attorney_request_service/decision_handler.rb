# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    class DecisionHandler
      DECISION_HANDLERS = {
        'declined' => ClaimsApi::PowerOfAttorneyRequestService::DeclinedDecisionHandler,
        'accepted' => ClaimsApi::PowerOfAttorneyRequestService::AcceptedDecisionHandler
      }.freeze

      # rubocop:disable Metrics/ParameterLists
<<<<<<< HEAD
      def initialize(decision:, proc_id:, representative_id:, poa_code:, metadata:, veteran:, claimant: nil)
=======
      def initialize(decision:, ptcpnt_id:, proc_id:, representative_id:, poa_code:, metadata:, claimant_ptcpnt_id:)
>>>>>>> 58184e4087 (API-43735-gather-data-for-poa-accept-2)
        @decision = decision
        @proc_id = proc_id
        @registration_number = registration_number
        @poa_code = poa_code
        @metadata = metadata
<<<<<<< HEAD
        @veteran = veteran
        @claimant = claimant
=======
        @claimant_ptcpnt_id = claimant_ptcpnt_id
>>>>>>> 58184e4087 (API-43735-gather-data-for-poa-accept-2)
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
<<<<<<< HEAD
<<<<<<< HEAD
            registration_number: @registration_number,
=======
            representative_id: @representative_id,
>>>>>>> 1255e92ce7 (WIP)
            metadata: @metadata,
            veteran: @veteran,
            claimant: @claimant
=======
            metadata: @metadata,
            claimant_ptcpnt_id: @claimant_ptcpnt_id
>>>>>>> 58184e4087 (API-43735-gather-data-for-poa-accept-2)
          ).call
        end
      end
    end
  end
end
