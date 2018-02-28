# frozen_string_literal: true

module V0
  module Profile
    class EmailsController < ApplicationController
      before_action { authorize :evss, :access? }

      # Fetches the email address, and its effective datetime, for the current user
      #
      # @return [Response] Sample response.body:
      #   {
      #     "data" =>
      #       {
      #         "id" => "",
      #         "type" => "evss_pciu_email_address_responses",
      #         "attributes" =>
      #           {
      #             "email" => "test2@test1.net",
      #             "effective_at" => "2018-02-27T14:41:32.283Z"
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
