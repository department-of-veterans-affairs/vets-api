# frozen_string_literal: true

require 'va_profile/configuration'

module VAProfile
  module V3
    module AddressValidation
      class Configuration < VAProfile::Configuration
        def base_path
          "#{VAProfile::Configuration::SETTINGS.address_validation.url}/services/address-validation/v3/"
        end

        def base_request_headers
          super.merge('apiKey' => VAProfile::Configuration::SETTINGS.address_validation.api_key)
        end

        def service_name
          'VAProfile/V3/AddressValidation'
        end
      end
    end
  end
end
