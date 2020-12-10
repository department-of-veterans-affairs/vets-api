# frozen_string_literal: true

require 'common/exceptions'
require 'vet360/address_validation/configuration'
require 'vet360/address_validation/address_suggestions_response'
require 'vet360/service'

module Vet360
  module AddressValidation
    # Wrapper for the VA profile address validation/suggestions API
    class Service < Vet360::Service
      configuration Vet360::AddressValidation::Configuration

      def initialize; end

      # Get address suggestions and override key from the VA profile API
      # @return [Vet360::AddressValidation::AddressSuggestionsResponse] response wrapper around address suggestions data
      def address_suggestions(address)
        candidate_res = candidate(address)

        AddressSuggestionsResponse.new(candidate_res)
      end

      # @return [Hash] raw data from VA profile address validation API including
      #   address suggestions, validation key, and address errors
      def candidate(address)
        begin
          res = perform(
            :post,
            'candidate',
            address.address_validation_req.to_json
          )
        rescue => e
          handle_error(e)
        end

        res.body
      end

      private

      def handle_error(error)
        raise error unless error.is_a?(Common::Client::Errors::ClientError)

        save_error_details(error)
        raise_invalid_body(error, self.class) unless error.body.is_a?(Hash)

        raise Common::Exceptions::BackendServiceException.new(
          'VET360_AV_ERROR',
          detail: error.body
        )
      end
    end
  end
end
