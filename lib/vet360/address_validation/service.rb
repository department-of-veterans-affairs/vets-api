# frozen_string_literal: true

module Vet360
  module AddressValidation
    class Service < Vet360::Service
      configuration Vet360::AddressValidation::Configuration

      def initialize
      end

      def candidate(address)
        res = perform(
          :post,
          'candidate',
          address.address_validation_req
        )
        binding.pry; fail
      end
    end
  end
end
