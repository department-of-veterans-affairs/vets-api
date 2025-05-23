# frozen_string_literal: true

module SignIn
  module Webhooks
    class LogingovController < ApplicationController
      skip_before_action :verify_authenticity_token

      def risc
        jwt = request.raw_post

        begin
          SignIn::Logingov::Service.new.jwt_decode(jwt)

          head :accepted
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
end
