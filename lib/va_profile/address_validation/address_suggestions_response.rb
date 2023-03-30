# frozen_string_literal: true

require 'va_profile/models/validation_address'
require 'va_profile/address_validation/service'

module VAProfile
  module AddressValidation
    # Wrapper for response from VA profile address validation API.
    # Contains address suggestions and validation key used to ignore suggested addresses
    # and use original address.
    class AddressSuggestionsResponse
      def initialize(candidate_res)
        validation_key = candidate_res['candidate_addresses'][0]['address_meta_data']['validation_key']

        @response = {
          addresses: candidate_res['candidate_addresses'].map do |address_suggestion_hash|
            {
              address: VAProfile::Models::ValidationAddress.build_from_address_suggestion(
                address_suggestion_hash
              ).to_h.compact,
              address_meta_data: address_suggestion_hash['address_meta_data'].except('validation_key')
            }
          end,
          validation_key:
        }
      end

      def to_json(*_args)
        @response.to_json
      end
    end
  end
end
