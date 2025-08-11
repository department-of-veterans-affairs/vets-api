# frozen_string_literal: true

module V0
  module Profile
    class PaymentHistoryController < ApplicationController
      service_tag 'payment-history'
      before_action { authorize :bgs, :access? }

      def index
        payment_history = PaymentHistory.new(payments: adapter.payments, return_payments: adapter.return_payments)
        render json: PaymentHistorySerializer.new(payment_history)
      end

      private

      def adapter
        @adapter ||= Adapters::PaymentHistoryAdapter.new(bgs_service_response)
      end

      def bgs_service_response
        person = BGS::People::Request.new.find_person_by_participant_id(user: current_user)
        payment_history = BGS::PaymentService.new(current_user).payment_history(person)

        if payment_history.nil?
          Rails.logger.error('BGS::PaymentService returned nil', {
                               person_status: person.status,
                               user_uuid: current_user&.uuid
                             })
        end

        payment_history
      end
    end
  end
end
