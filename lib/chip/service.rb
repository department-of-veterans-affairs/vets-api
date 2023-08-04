# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require_relative 'configuration'
require_relative 'redis_client'

module Chip
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring

    configuration Chip::Configuration
    STATSD_KEY_PREFIX = 'api.chip'

    attr_reader :tenant_name, :tenant_id, :username, :password, :redis_client

    ##
    # Builds a Service instance
    #
    # @param opts [Hash] options to create the object
    # @option opts [String] :tenant_name
    # @option opts [String] :tenant_id
    # @option opts [String] :username
    # @option opts [String] :password
    #
    # @return [Service] an instance of this class
    #
    def self.build(opts = {})
      new(opts)
    end

    def initialize(opts = {})
      @tenant_name = opts[:tenant_name]
      @tenant_id = opts[:tenant_id]
      @username = opts[:username]
      @password = opts[:password]
      validate_arguments!

      @redis_client = RedisClient.build(tenant_id)
      super()
    end

    ##
    # Get the auth token from CHIP
    #
    # @return [Faraday::Response] response from CHIP token endpoint
    #
    def get_token
      with_monitoring do
        perform(:post, "/#{config.base_path}/token", {}, token_headers)
      end
    end

    private

    def request_headers
      default_headers.merge('Authorization' => "Bearer #{token}")
    end

    def token_headers
      claims_token = Base64.encode64("#{username}:#{password}")
      default_headers.merge('Authorization' => "Basic #{claims_token}")
    end

    def default_headers
      {
        'Content-Type' => 'application/json',
        'x-apigw-api-id' => config.api_gtwy_id
      }
    end

    def token
      @token ||= begin
        token = redis_client.get
        if token.present?
          token
        else
          resp = get_token

          Oj.load(resp.body)&.fetch('token').tap do |jwt_token|
            redis_client.save(token: jwt_token)
          end
        end
      end
    end

    def validate_arguments!
      raise ArgumentError, 'Invalid username' if username.blank?
      raise ArgumentError, 'Invalid password' if password.blank?
      raise ArgumentError, 'Invalid tenant parameters' if tenant_name.blank? || tenant_id.blank?
      raise ArgumentError, 'Tenant parameters do not exist' unless config.valid_tenant?(tenant_name:, tenant_id:)
    end
  end
end
