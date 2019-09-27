# frozen_string_literal: true

module Vet360
  module AddressValidation
    class Service < Vet360::Service
      configuration Vet360::AddressValidation::Configuration

      def candidate(address)
        perform(
          :post,
          'candidate',
        )
      end
    end
  end
end
