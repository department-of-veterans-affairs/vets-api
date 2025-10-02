# frozen_string_literal: true

require 'va_profile/models/validation_address'
require_relative 'service'

module VAProfile
  module AddressValidation
    module V3
      # Wrapper for response from VA profile address validation API.
      # Contains address suggestions and validation key used to ignore suggested addresses
      # and use original address.
      class AddressSuggestionsResponse
        def initialize(candidate_res, validate: false)
          override_validation_key = candidate_res['override_validation_key']
          candidate_res['validation_key'] = override_validation_key
          if validate
            validation_response(candidate_res)
          else
            candidate_response(candidate_res)
          end
        end

        def candidate_response(response)
          @response = {
            addresses: response['candidate_addresses'].map do |address_suggestion_hash|
              {
                address: VAProfile::Models::ValidationAddress.build_from_address_suggestion(
                  address_suggestion_hash
                ).attributes.compact,
                address_meta_data: VAProfile::Models::ValidationAddress.build_address_metadata(
                  address_suggestion_hash
                ).to_h
              }
            end,
            override_validation_key: response['override_validation_key'],
            validation_key: response['validation_key']
          }
        end

        def validation_response(response)
          address_suggestion_hash = response['address']
          @response = {
            addresses: [
              {
                address: VAProfile::Models::ValidationAddress.build_from_address_suggestion(
                  address_suggestion_hash
                ).attributes.compact,
                address_meta_data: VAProfile::Models::ValidationAddress.build_address_metadata(
                  address_suggestion_hash
                ).to_h
              }
            ],
            override_validation_key: response['override_validation_key'],
            validation_key: response['validation_key'],
            validated: true
          }
        end

        def to_json(*_args)
          @response.to_json
        end
      end
    end
  end
end
