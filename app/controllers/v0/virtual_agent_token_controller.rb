# frozen_string_literal: true

module V0
  class VirtualAgentTokenController < ApplicationController
    skip_before_action :authenticate, only: [:create]

    def create
      render json: { token: fetch_connector_token }
    end

    private

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

      token_endpoint = 'https://directline.botframework.com/v3/directline/tokens/generate'
      @token_uri = URI(token_endpoint)
    end

    def bearer_token
      @bearer_token ||= 'Bearer ' + Settings.virtual_agent.webchat_secret
    end
  end
end
