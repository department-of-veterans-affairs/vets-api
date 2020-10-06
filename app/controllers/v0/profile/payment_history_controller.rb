# frozen_string_literal: true

module V0
  module Profile
    class PaymentHistoryController < ApplicationController
      before_action { authorize :bgs, :access? }

      def index
        person = BGS::PeopleService.new(current_user).find_person_by_participant_id
        response = BGS::PaymentService.new(current_user).payment_history(person)

        render(
          json: response,
          serializer: VetPaymentHistorySerializer
        )
      end
    end
  end
end
