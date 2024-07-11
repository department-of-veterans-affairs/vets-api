# frozen_string_literal: true

require 'sign_in/logger'

module V0
  module SignIns
    class TokenController < SignIn::ApplicationController
      skip_before_action :authenticate, only: %i[token]

      def token
        SignIn::TokenParamsValidator.new(params: token_params).perform

        sign_in_logger.info('token')
        StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_TOKEN_SUCCESS)

        render json: response_body, status: :ok
      rescue SignIn::Errors::StandardError => e
        sign_in_logger.info('token error', { errors: e.message })
        StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_TOKEN_FAILURE)
        render json: { errors: e }, status: :bad_request
      end

      private

      def token_params
        params.permit(:grant_type, :code, :code_verifier, :client_assertion, :client_assertion_type,
                      :assertion, :subject_token, :subject_token_type, :actor_token, :actor_token_type, :client_id)
      end

      def response_body
        SignIn::TokenResponseGenerator.new(params: token_params, cookies: token_cookies).perform
      end

      def token_cookies
        @token_cookies ||= defined?(cookies) ? cookies : nil
      end

      def sign_in_logger
        @sign_in_logger = SignIn::Logger.new(prefix: self.class)
      end
    end
  end
end
