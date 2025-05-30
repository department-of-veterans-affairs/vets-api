# frozen_string_literal: true

module V0
  module VirtualAgent
    class UsersController < SignIn::ServiceAccountApplicationController
      service_tag 'identity'

      before_action :authenticate_one_time_code

      def show
        raise Common::Client::Errors::ClientError unless @icn

        render json: { icn: @icn }, status: :ok
      rescue Common::Client::Errors::ClientError
        render json: invalid_code_error, status: :bad_request
      end

      private

      def authenticate_one_time_code
        chatbot_code_container = ::Chatbot::CodeContainer.find(params[:code])

        @icn = chatbot_code_container&.icn
      ensure
        chatbot_code_container&.destroy
      end

      def invalid_code_error
        {
          error: 'invalid_request',
          error_description: 'Code is not valid.'
        }
      end
    end
  end
end
