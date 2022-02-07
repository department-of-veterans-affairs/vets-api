# frozen_string_literal: true

module V0
  module Profile
    class PaymentHistoryController < ApplicationController
      before_action { authorize :bgs, :access? }

      def index
        render(
          json: PaymentHistory.new(payments: adapter.payments, return_payments: adapter.return_payments),
          serializer: PaymentHistorySerializer
        )
      end

      private

      def adapter
        @adapter ||= Adapters::PaymentHistoryAdapter.new(bgs_service_response)
      end

      def bgs_service_response
        person = BGS::PeopleService.new(current_user).find_person_by_participant_id
        BGS::PaymentService.new(current_user).payment_history(person)
      end
    end
  end
end
