# frozen_string_literal: true

require 'va_profile/configuration'

module VAProfile
  module AddressValidation
    class Configuration < VAProfile::Configuration
      def base_path
        "https://#{VAProfile::Configuration::SETTINGS.address_validation.hostname}/services/address_validation/v2/"
      end

      def base_request_headers
        super.merge('apiKey' => VAProfile::Configuration::SETTINGS.address_validation.api_key)
      end

      def service_name
        'VAProfile/AddressValidation'
      end
    end
  end
end
