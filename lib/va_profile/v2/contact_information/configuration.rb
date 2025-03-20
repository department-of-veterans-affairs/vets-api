# frozen_string_literal: true

require 'va_profile/configuration'

module VAProfile
  module V2
    module ContactInformation
      class Configuration < VAProfile::Configuration
        self.read_timeout = VAProfile::Configuration::SETTINGS.contact_information.timeout || 30

        def base_path
          "#{VAProfile::Configuration::SETTINGS.url}/contact-information-hub/contact-information/v2"
        end

        def service_name
          'VAProfile/V2/ContactInformation'
        end

        def mock_enabled?
          VAProfile::Configuration::SETTINGS.contact_information.mock || false
        end

        def connection
          ssl_enabled = Rails.env.production?
          @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options,
                                           ssl: { verify: ssl_enabled }) do |faraday|
            faraday.use      :breakers
            faraday.use      Faraday::Response::RaiseError
            faraday.use :mock, cassette_dir: 'va_profile/v2/contact_information'
            faraday.response :snakecase, symbolize: false
            faraday.response :json, content_type: /\bjson/ # ensures only json content types parsed
            # faraday.response :betamocks if mock_enabled?
            faraday.adapter Faraday.default_adapter
          end
        end
      end
    end
  end
end
