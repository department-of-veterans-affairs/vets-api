# frozen_string_literal: true

require 'erb'

module V0
  class VirtualAgentTokenController < ApplicationController
    skip_before_action :authenticate, only: [:create]

    rescue_from 'V0::VirtualAgentTokenController::ServiceException', with: :service_exception_handler
    rescue_from Net::HTTPError, with: :service_exception_handler

    def create
      directline_response = fetch_connector_values
      render json: { token: directline_response[:token],
                     conversationId: directline_response[:conversationId],
                     apiSession: ERB::Util.url_encode(cookies[:api_session]) }
    end

    private

    def fetch_connector_values
      connector_response = request_connector_values
      parse_connector_values(connector_response)
    end

    def request_connector_values
      req = Net::HTTP::Post.new(token_endpoint_uri)
      req['Authorization'] = bearer_token
      Net::HTTP.start(token_endpoint_uri.hostname, token_endpoint_uri.port, use_ssl: true) do |http|
        http.request(req)
      end
    end

    def parse_connector_values(response)
      raise ServiceException.new(response.body), response.body unless response.code == '200'

      {
        token: JSON.parse(response.body)['token'],
        conversationId: JSON.parse(response.body)['conversationId']
      }
    end

    def token_endpoint_uri
      return @token_uri if @token_uri.present?

      token_endpoint = 'https://directline.botframework.com/v3/directline/tokens/generate'
      @token_uri = URI(token_endpoint)
    end

    def bearer_token
      secret = if Flipper.enabled?(:virtual_agent_enable_pva2_chatbot, current_user)
                 Settings.virtual_agent.webchat_pva2_secret
               else
                 Settings.virtual_agent.webchat_secret
               end
      @bearer_token ||= "Bearer #{secret}"
    end

    def service_exception_handler(exception)
      context = 'An error occurred with the Microsoft service that issues chatbot tokens'
      log_exception_to_sentry(exception, 'context' => context)
      render nothing: true, status: :service_unavailable
    end

    class ServiceException < RuntimeError; end
  end
end
