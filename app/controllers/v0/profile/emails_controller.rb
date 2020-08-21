# frozen_string_literal: true

require 'common/exceptions/validation_errors'
require 'evss/pciu/service'

module V0
  module Profile
    class EmailsController < ApplicationController
      include EVSS::Authorizeable

      before_action :authorize_evss!

      def show
        response = service.get_email_address

        render json: response, serializer: EmailSerializer
      end

      def create
        email_address = EVSS::PCIU::EmailAddress.new email_params

        if email_address.valid?
          response = service.post_email_address email_address

          render json: response, serializer: EmailSerializer
        else
          raise Common::Exceptions::ValidationErrors, email_address
        end
      end

      private

      def service
        EVSS::PCIU::Service.new @current_user
      end

      def email_params
        params.permit(:email)
      end
    end
  end
end
