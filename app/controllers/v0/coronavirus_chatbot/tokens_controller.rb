# frozen_string_literal: true

module V0
  module CoronavirusChatbot
    class TokensController < ApplicationController
      skip_before_action :authenticate, only: [:create]

      rescue_from 'V0::CoronavirusChatbot::TokensController::ServiceException', with: :service_exception_handler
      rescue_from Net::HTTPError, with: :service_exception_handler

      def create
        token = JWT.encode token_payload, Settings.coronavirus_chatbot.app_secret, 'HS256'

        render json: { token: token }
      end

      private

      def token_payload
        {
          locale: params[:locale],
          directLineURI: Settings.coronavirus_chatbot.directline_uri,
          connectorToken: fetch_connector_token,
          userId: chat_bot_user_id
        }
      end

      def chat_bot_user_id
        SecureRandom.hex(8)
      end

      def fetch_connector_token
        connector_response = request_connector_token
        parse_connector_token(connector_response)
      end

      def request_connector_token
        req = Net::HTTP::Post.new(token_endpoint_uri)
        req['Authorization'] = bearer_token
        Net::HTTP.start(token_endpoint_uri.hostname, token_endpoint_uri.port, use_ssl: true) do |http|
          http.request(req)
        end
      end

      def parse_connector_token(response)
        raise ServiceException.new(response.body), response.body unless response.code == '200'

        JSON.parse(response.body)['token']
      end

      def token_endpoint_uri
        return @token_uri if @token_uri.present?

        token_endpoint = "https://#{Settings.coronavirus_chatbot.directline_uri || 'directline.botframework.com'}" \
                         '/v3/directline/tokens/generate'
        @token_uri = URI(token_endpoint)
      end

      def bearer_token
        @bearer_token ||= "Bearer #{Settings.coronavirus_chatbot.webchat_secret}"
      end

      def service_exception_handler(exception)
        context = 'An error occurred with the Microsoft service that issues chatbot tokens'
        log_exception_to_sentry(exception, 'context' => context)
        render nothing: true, status: :service_unavailable
      end

      class ServiceException < RuntimeError; end
    end
  end
end
