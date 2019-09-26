# frozen_string_literal: true

module Vet360
  module AddressValidation
    class Configuration < Vet360::Configuration
      def base_path
        "https://dev-api.va.gov/services/address_validation/v1/"
      end

      def service_name
        'Vet360/AddressValidation'
      end
    end
  end
end
