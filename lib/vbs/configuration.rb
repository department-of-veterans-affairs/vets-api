# frozen_string_literal: true

require 'common/client/configuration/rest'

module VBS
  class Configuration < Common::Client::Configuration::REST
    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
        faraday.request :json
        faraday.response :json
        faraday.adapter Faraday.default_adapter
      end
    end

    def mock_enabled?
      false
    end

    def base_path
      Settings.vbs.url
    end

    def service_name
      'VBS'
    end
  end
end
