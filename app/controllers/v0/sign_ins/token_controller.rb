# frozen_string_literal: true

require 'sign_in/logger'

module V0
  module SignIns
    class TokenController < SignIn::ApplicationController
      skip_before_action :authenticate, only: %i[token]

      def token
        SignIn::TokenParamsValidator.new(params: token_params).perform
        increment_statsd_success_metric

        render json: token_response, status: :ok
      rescue SignIn::Errors::StandardError => e
        increment_statsd_failure_metric(e)
        render json: { errors: e }, status: :bad_request
      end

      private

      def token_params
        params.permit(:grant_type, :code, :code_verifier, :client_assertion, :client_assertion_type,
                      :assertion, :subject_token, :subject_token_type, :actor_token, :actor_token_type, :client_id)
      end

      def token_cookies
        @token_cookies ||= defined?(cookies) ? cookies : nil
      end

      def token_response
        return @token_response if defined?(@token_response)

        @token_response = SignIn::TokenResponseGenerator.new(params: token_params, cookies: token_cookies).perform
      end

      def sign_in_logger
        @sign_in_logger = SignIn::Logger.new(prefix: self.class)
      end

      def increment_statsd_success_metric
        sign_in_logger.info('token')
        StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_TOKEN_SUCCESS)
      end

      def increment_statsd_failure_metric(error)
        sign_in_logger.info('token error', { errors: error.message })
        StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_TOKEN_FAILURE)
      end
    end
  end
end
