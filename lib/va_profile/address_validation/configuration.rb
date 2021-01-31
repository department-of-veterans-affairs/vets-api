# frozen_string_literal: true

require 'vet360/configuration'

module VAProfile
  module AddressValidation
    class Configuration < VAProfile::Configuration
      def base_path
        "https://#{Settings.vet360.address_validation.hostname}/services/address_validation/v2/"
      end

      def base_request_headers
        super.merge('apiKey' => Settings.vet360.address_validation.api_key)
      end

      def service_name
        'VAProfile/AddressValidation'
      end
    end
  end
end
