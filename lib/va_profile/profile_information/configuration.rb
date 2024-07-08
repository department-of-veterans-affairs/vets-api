# frozen_string_literal: true

require 'va_profile/configuration'

module VAProfile
  module ProfileInformation
    class Configuration < VAProfile::Configuration
      self.read_timeout = VAProfile::Configuration::SETTINGS.profile_information.timeout || 30

      def base_path
        "#{VAProfile::Configuration::SETTINGS.url}/contact-information-hub/cuf/contact-information/v2"
      end

      def post(path, body = {})
        connection.post(path, body)
      end

      def connection
        @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
          faraday.use :breakers
          faraday.request :json
          faraday.use      Faraday::Response::RaiseError

          faraday.response :snakecase, symbolize: false
          faraday.response :json, content_type: /\bjson/ # ensures only json content types parsed
          faraday.response :betamocks if mock_enabled?
          faraday.adapter Faraday.default_adapter
        end
      end

      def service_name
        'VAProfile/ProfileInformation'
      end

      def mock_enabled?
        VAProfile::Configuration::SETTINGS.profile_information.use_mocks || false
      end
    end
  end
end
