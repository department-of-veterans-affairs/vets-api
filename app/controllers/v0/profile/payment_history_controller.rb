# frozen_string_literal: true

module V0
  module Profile
    class PaymentHistoryController < ApplicationController
      before_action { authorize :bgs, :access? }

      def index
        service = BGS::PaymentService.new(current_user)
        response = service.payment_history

        render(
          json: response,
          serializer: VetPaymentHistorySerializer
        )
      end
    end
  end
end
