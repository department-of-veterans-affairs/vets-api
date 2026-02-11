# frozen_string_literal: true

require 'common/client/configuration/rest'

module UnifiedHealthData
  class FacilityConfiguration < Common::Client::Configuration::REST
    # Explicit type coercion for timeout - handles nil, strings, or unexpected types from Parameter Store
    timeout_value = Settings.va_mobile.timeout.to_i
    self.read_timeout = timeout_value.positive? ? timeout_value : 55

    def base_path
      Settings.va_mobile.url
    end

    def service_name
      'UHDFacility'
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
        conn.use(:breakers, service_name:)
        conn.request :json

        conn.response :raise_custom_error, error_prefix: service_name
        conn.response :betamocks if mock_enabled?

        conn.adapter Faraday.default_adapter
      end
    end

    def mock_enabled?
      # Explicit boolean coercion - handles "false" strings, 0, or other unexpected types from Parameter Store
      ActiveModel::Type::Boolean.new.cast(Settings.mhv.uhd.mock)
    end
  end
end
