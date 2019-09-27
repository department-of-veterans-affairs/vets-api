# frozen_string_literal: true

module Vet360
  module AddressValidation
    class Service < Vet360::Service
      configuration Vet360::AddressValidation::Configuration

      def city_state_province(zip_code)
        perform(:get, "cityStateProvince/#{zip_code}")
        binding.pry; fail
      end
    end
  end
end
