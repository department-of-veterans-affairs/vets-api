# frozen_string_literal: true

module V0
  class LoginGovCallbackController < ApplicationController
    skip_before_action :verify_authenticity_token

    def risc
      jwt = request.raw_post

      begin
        decoded_token = SignIn::Logingov::Service.new.jwt_decode(jwt)

        # parser logic

        render json: { message: 'JWT received and decoded', decoded: decoded_token }, status: :ok
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
