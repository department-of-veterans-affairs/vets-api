# frozen_string_literal: true

require 'common/client/configuration/rest'

module Vetext
  class Configuration < Common::Client::Configuration::REST
    self.read_timeout = Settings.va_mobile.timeout || 15

    def base_path
      Settings.vetext.url
    end

    def service_name
      'Vetext'
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
        conn.use :breakers
        conn.request :camelcase
        conn.request :json

        if ENV['DEBUG'] && !Rails.env.production?
          conn.request(:curl, ::Logger.new(STDOUT), :warn)
          conn.response(:logger, ::Logger.new(STDOUT), bodies: true)
        end

        conn.response :betamocks if mock_enabled?
        conn.response :snakecase
        conn.response :json, content_type: /\bjson$/
        conn.adapter Faraday.default_adapter
      end
    end

    def mock_enabled?
      [true, 'true'].include?(Settings.vetext.mock)
    end
  end
end
