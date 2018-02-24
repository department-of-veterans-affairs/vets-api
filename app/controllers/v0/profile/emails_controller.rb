# frozen_string_literal: true

module V0
  module Profile
    class EmailsController < ApplicationController
      before_action { authorize :evss, :access? }

      # Fetches the email address for the current user
      #
      # @return [Response] Sample response.body:
      #   {
      #     "data" =>
      #       {
      #         "id" => "",
      #         "type" => "evss_pciu_email_address_responses",
      #         "attributes" =>
      #           {
      #             "email" => "test2@test1.net"
      #           }
      #       }
      #   }
      #
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
