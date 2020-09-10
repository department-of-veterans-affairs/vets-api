# frozen_string_literal: true

require 'vet360/configuration'

module Vet360
  module AddressValidation
    class Configuration < Vet360::Configuration
      def base_path
        "https://#{Settings.vet360.address_validation.hostname}/services/address_validation/v2/"
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
