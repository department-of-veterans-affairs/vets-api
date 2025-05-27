# frozen_string_literal: true

module SignIn
  module Webhooks
    class LogingovController < SignIn::ServiceAccountApplicationController
      before_action :authenticate_service_account

      def risc
        head :accepted
      end

      private

      def authenticate_service_account
        jwt = request.raw_post

        @risc_jwt = SignIn::Logingov::Service.new.jwt_decode(jwt)
      rescue SignIn::Logingov::Errors::JWTDecodeError => e
        Rails.logger.error("Login.gov RISC decode error: #{e.message}")
        render json: { error: 'Invalid JWT' }, status: :unauthorized
      rescue => e
        Rails.logger.error("Login.gov RISC unexpected error: #{e.class} - #{e.message}")
        render json: { error: 'Unexpected error' }, status: :internal_server_error
      end
    end
  end
end
