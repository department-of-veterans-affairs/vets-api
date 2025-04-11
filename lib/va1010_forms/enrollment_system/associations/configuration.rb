# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/response/json_parser'

module VA1010Forms
  module EnrollmentSystem
    module Associations
      class Configuration < Common::Client::Configuration::REST
        def base_path
          "#{Settings.va1010_forms.enrollment_system.associations.host}/"
        end

        def service_name
          'VA1010Forms'
        end

        # @return [Hash] The basic headers required for any VES Associations API call.
        def self.base_request_headers
          super.merge('apiKey' => Settings.va1010_forms.enrollment_system.associations.api_key)
        end

        def connection
          Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
            conn.use(:breakers, service_name:)
            conn.request :json
            conn.options.open_timeout = Settings.va1010_forms.open_timeout
            conn.options.timeout = Settings.va1010_forms.timeout
            conn.response :json_parser
            conn.adapter Faraday.default_adapter
          end
        end
      end
    end
  end
end
