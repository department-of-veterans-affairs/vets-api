# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require_relative 'configuration'

module Chip
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring
    STATSD_KEY_PREFIX = 'api.chip'

    configuration Chip::Configuration

    def perform_post_with_token(token:, path:)
      config.connection.post(path) do |req|
        req.headers = default_headers.merge('Authorization' => "Bearer #{token}")
      end
    end

    def perform_get_with_token(token:, path:)
      config.connection.get(path) do |req|
        req.headers = default_headers.merge('Authorization' => "Bearer #{token}")
      end
    end

    def token
      config.connection.post('/token') do |req|
        req.headers = default_headers.merge('Authorization' => "Basic #{claims_token}")
      end
    end

    private

    def claims_token
      @claims_token ||= Base64.encode64("#{config.api_username}:#{config.api_user}")
    end

    ##
    # Build a hash of default headers for CHIP HTTP requests
    #
    # @return [Hash]
    #
    def default_headers
      {
        'Content-Type' => 'application/json',
        'x-apigw-api-id' => config.api_id
      }
    end
  end
end
