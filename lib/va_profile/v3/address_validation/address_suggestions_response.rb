# frozen_string_literal: true

require 'va_profile/models/v3/validation_address'
require_relative 'service'

module VAProfile
  module V3
    module AddressValidation
      # Wrapper for response from VA profile address validation API.
      # Contains address suggestions and validation key used to ignore suggested addresses
      # and use original address.
      class AddressSuggestionsResponse
        def initialize(candidate_res)
          override_validation_key = candidate_res['override_validation_key']
          @response = {
            addresses: candidate_res['candidate_addresses'].map do |address_suggestion_hash|
              {
                address: VAProfile::Models::V3::ValidationAddress.build_from_address_suggestion(
                  address_suggestion_hash
                ).to_h.compact,
                address_meta_data: VAProfile::Models::V3::ValidationAddress.build_address_metadata(
                  address_suggestion_hash
                ).to_h
              }
            end,
            override_validation_key:
          }
        end

        def to_json(*_args)
          @response.to_json
        end
      end
    end
  end
end
