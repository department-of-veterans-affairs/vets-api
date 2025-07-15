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
      def initialize(decision:, ptcpnt_id:, proc_id:, representative_id:, poa_code:, metadata:)
        @decision = decision
        @ptcpnt_id = ptcpnt_id
        @proc_id = proc_id
        @representative_id = representative_id
        @poa_code = poa_code
        @metadata = metadata
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
            ptcpnt_id: @ptcpnt_id,
            proc_id: @proc_id,
            representative_id: @representative_id
          ).call
        end

        if @decision == 'accepted'
          handler_class.new(
            ptcpnt_id: @ptcpnt_id,
            proc_id: @proc_id,
            poa_code: @poa_code,
            metadata: @metadata
          ).call
        end
      end
    end
  end
end
