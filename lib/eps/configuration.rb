# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/request/camelcase'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/snakecase'
require 'faraday/multipart'
require_relative '../../modules/vaos/app/services/vaos/middleware/response/errors'
require_relative '../../modules/vaos/app/services/eps/middleware/response/errors'

module Eps
  class Configuration < Common::Client::Configuration::REST
    delegate :access_token_url, :api_url, :base_path, :grant_type, :scopes, :client_assertion_type,
             :pagination_timeout_seconds, to: :settings

    def settings
      Settings.vaos.eps
    end

    def service_name
      'EPS'
    end

    def mock_enabled?
      settings.mock
    end

    def connection
      Faraday.new(api_url, headers: base_request_headers, request: request_options) do |conn|
        conn.use(:breakers, service_name:)
        conn.request :camelcase
        conn.request :json

        # Enable debug logging in development by default, but without response bodies to prevent PII exposure
        if (ENV['VAOS_EPS_DEBUG'] || Rails.env.development?) && !Rails.env.production?
          conn.request(:curl, ::Logger.new($stdout), :warn)
          conn.response(:logger, ::Logger.new($stdout), bodies: true)
        end

        conn.response :betamocks if mock_enabled?
        conn.response :snakecase
        conn.response :json_parser
        conn.response :eps_errors
        conn.adapter Faraday.default_adapter
      end
    end
  end
end
