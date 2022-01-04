# frozen_string_literal: true

require 'evss/pciu/service'

module V0
  module Profile
    class PrimaryPhonesController < ApplicationController
      include EVSS::Authorizeable

      before_action :authorize_evss!

      def show
        response = service.get_primary_phone

        render json: response, serializer: PhoneNumberSerializer
      end

      def create
        phone = EVSS::PCIU::PhoneNumber.new primary_phone_params

        if phone.valid?
          response = service.post_primary_phone phone
          Rails.logger.warn('PrimaryPhonesController#create request completed', sso_logging_info)

          render json: response, serializer: PhoneNumberSerializer
        else
          raise Common::Exceptions::ValidationErrors, phone
        end
      end

      private

      def service
        EVSS::PCIU::Service.new @current_user
      end

      def primary_phone_params
        params.permit(:country_code, :number, :extension, :effective_date)
      end
    end
  end
end
