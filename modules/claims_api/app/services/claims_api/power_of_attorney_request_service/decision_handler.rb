# frozen_string_literal: true

require_relative 'declined_decision_handler'

module ClaimsApi
  module PowerOfAttorneyRequestService
    class DecisionHandler
      DECISION_HANDLERS = {
        'declined' => ClaimsApi::PowerOfAttorneyRequestService::DeclinedDecisionHandler
      }.freeze

      def initialize(decision:, ptcpnt_id:, proc_id:, representative_id:)
        @decision = decision
        @ptcpnt_id = ptcpnt_id
        @proc_id = proc_id
        @representative_id = representative_id
      end

      def call
        handler_class = DECISION_HANDLERS[@decision]
        return unless handler_class

        handler_class.new(
          ptcpnt_id: @ptcpnt_id,
          proc_id: @proc_id,
          representative_id: @representative_id
        ).call
      end
    end
  end
end
