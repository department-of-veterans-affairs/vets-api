# frozen_string_literal: true

module Eps
  class Configuration < Common::Client::Configuration::REST
    delegate :access_token_url, :api_url, :grant_type, :scopes, :client_assertion_type, to: 'Settings.vaos.eps'

    def login_url
      access_token_url
    end

    def base_path
      api_url
    end

    def scope
      scopes
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
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

    private

    def base_request_headers
      # Define your base request headers here
    end

    def request_options
      # Define your request options here
    end

    def mock_enabled?
      # Define your mock enabled logic here
    end
  end
end
