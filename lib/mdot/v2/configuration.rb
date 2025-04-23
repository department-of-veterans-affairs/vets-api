# frozen_string_literal: true

module MDOT::V2
  class Configuration < Common::Client::Configuration::REST
    self.request_types = %i[get post]

    def base_path
      Settings.mdot_v2.url
    end

    def service_name
      'MDOT_V2'
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
        # faraday.use(:breakers, service_name:)
        # faraday.request :camelcase
        faraday.request :json

        # faraday.response :snakecase
        faraday.response :raise_custom_error, error_prefix: service_name
        faraday.response :betamocks if mock_enabled?
        faraday.response :json

        faraday.adapter Faraday.default_adapter
      end
    end

    def breakers_enabled?
      Settings.mdot.breakers || false
    end

    def mock_enabled?
      Settings.mdot.mock || false
    end
  end
end