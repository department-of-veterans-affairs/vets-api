# frozen_string_literal: true

require 'common/client/configuration/rest'

module Avs
  class Configuration < Common::Client::Configuration::REST
    self.read_timeout = Settings.avs.timeout || 55

    def base_path
      Settings.avs.url
    end

    def service_name
      'Avs'
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
        conn.use(:breakers, service_name:)
        conn.request :camelcase
        conn.request :json

        if ENV['AVS_DEBUG'] && !Rails.env.production?
          conn.request(:curl, ::Logger.new($stdout), :warn)
          conn.response(:logger, ::Logger.new($stdout), bodies: true)
        end

        conn.response :betamocks if mock_enabled?
        conn.response :json_parser
        conn.adapter Faraday.default_adapter
      end
    end

    def self.base_request_headers
      token = Settings.avs.api_jwt
      super.merge('Authorization' => "Bearer #{token}")
    end

    def mock_enabled?
      [true, 'true'].include?(Settings.avs.mock)
    end
  end
end
