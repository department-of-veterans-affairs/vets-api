# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require_relative 'configuration'

module Chip
  class Client < Common::Client::Base
    include Common::Client::Concerns::Monitoring
    STATSD_KEY_PREFIX = 'api.chip'

    configuration Chip::Configuration
    attr_reader :username, :password

    def initialize(opts)
      @username = opts[:username]
      @password = opts[:password]
      validate_arguments!
      super()
    end

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
      @claims_token ||= Base64.encode64("#{@username}:#{@password}")
    end

    ##
    # Build a hash of default headers for CHIP HTTP requests
    #
    # @return [Hash]
    #
    def default_headers
      {
        'Content-Type' => 'application/json',
        'x-apigw-api-id' => config.api_gtwy_id
      }
    end

    def validate_arguments!
      raise ArgumentError, 'Invalid username' if @username.blank?
      raise ArgumentError, 'Invalid password' if @password.blank?
    end
  end
end
