# frozen_string_literal: true

module Vet360
  module AddressValidation
    class Configuration < Vet360::Configuration
      def base_path
        "https://dev-api.va.gov/services/address_validation/v1/"
      end

      def base_request_headers
        super.merge('apiKey' => Settings.vet360.address_validation.api_key)
      end

      def service_name
        'Vet360/AddressValidation'
      end
    end
  end
end
