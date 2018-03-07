# frozen_string_literal: true

module V0
  module Profile
    class EmailsController < ApplicationController
      before_action { authorize :evss, :access? }

      def show
        response = service.get_email_address

        render json: response, serializer: EmailSerializer
      end

      private

      def service
        EVSS::PCIU::Service.new @current_user
      end
    end
  end
end
