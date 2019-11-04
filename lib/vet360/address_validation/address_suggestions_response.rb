# frozen_string_literal: true

module Vet360
  module AddressValidation
    class AddressSuggestionsResponse
      def initialize(candidate_res, validation_key)
        @response = {
          addresses: candidate_res['candidate_addresses'].map do |address_suggestion_hash|
            {
              address: Vet360::Models::Address.build_from_address_suggestion(address_suggestion_hash).to_h.compact,
              address_meta_data: address_suggestion_hash['address_meta_data'].except('validation_key')
            }
          end,
          validation_key: validation_key
        }
      end

      def to_json(*_args)
        @response.to_json
      end
    end
  end
end
