# frozen_string_literal: true

require_relative '../vaos/middleware/response/errors'
require_relative '../vaos/middleware/vaos_logging'

module Eps
  class Configuration < Common::Client::Configuration::REST
    delegate :access_token_url, :api_url, :grant_type, :scopes, :client_assertion_type, to: :settings

    def settings
      Settings.vaos.eps
    end

    def service_name
      'EPS'
    end

    def mock_enabled?
      [true, 'true'].include?(settings.mock)
    end

    def connection
      Faraday.new(api_url, headers: base_request_headers, request: request_options) do |conn|
        conn.use :breakers
        conn.request :camelcase
        conn.request :json

        if ENV['VAOS_DEBUG'] && !Rails.env.production?
          conn.request(:curl, ::Logger.new($stdout), :warn)
          conn.response(:logger, ::Logger.new($stdout), bodies: true)
        end

        conn.response :betamocks if mock_enabled?
        conn.response :snakecase
        conn.response :json, content_type: /\bjson$/
        conn.response :vaos_errors
        conn.use :vaos_logging
        conn.adapter Faraday.default_adapter
      end
    end
  end
end
