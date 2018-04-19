# frozen_string_literal: true

module V0
  module Profile
    class AlternatePhonesController < ApplicationController
      before_action { authorize :evss, :access? }

      def show
        response = service.get_alternate_phone

        render json: response, serializer: PhoneNumberSerializer
      end

      def create
        phone = EVSS::PCIU::PhoneNumber.new alternate_phone_params

        if phone.valid?
          response = service.post_alternate_phone phone

          render json: response, serializer: PhoneNumberSerializer
        else
          raise Common::Exceptions::ValidationErrors, phone
        end
      end

      private

      def service
        EVSS::PCIU::Service.new @current_user
      end

      def alternate_phone_params
        params.permit(:country_code, :number, :extension, :effective_date)
      end
    end
  end
end
