# frozen_string_literal: true

require 'va_profile/configuration'

module VAProfile
  module V3
    module AddressValidation
      class Configuration < VAProfile::Configuration
        def base_path
          "https://#{VAProfile::Configuration::SETTINGS.address_validation.hostname}/services/address-validation/v3/"
        end

        def base_request_headers
          super.merge('apiKey' => VAProfile::Configuration::SETTINGS.v3.address_validation.api_key)
        end

        def service_name
          'VAProfile/V3/AddressValidation'
        end
      end
    end
  end
end
