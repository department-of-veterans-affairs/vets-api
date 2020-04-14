# frozen_string_literal: true

module Vet360
  module Models
    # Model for addresses sent and received from the VA profile address validation API
    class ValidationAddress < BaseAddress
      def initialize(*args)
        super
        # address validation api uses the same field for province and state codes
        # but our address model wants province used in intl addresses and
        # state_code used in domestic ones
        if address_type == INTERNATIONAL
          self.province ||= state_code
          self.state_code = nil
        end
      end

      # Convert a ValidationAddress into a hash that can be sent to the address validation
      # API
      # @return [Hash] hash that is formatted for POSTing to address validation API
      def address_validation_req
        Common::HashHelpers.deep_remove_blanks(
          requestAddress: attributes.slice(
            :address_line1,
            :address_line2,
            :address_line3,
            :city,
            :international_postal_code
          ).deep_transform_keys { |k| k.to_s.camelize(:lower) }.merge(
            requestCountry: {
              countryCode: @country_code_iso3
            },
            addressPOU: @address_pou,
            stateProvince: {
              code: @state_code,
              name: @province
            },
            zipCode5: @zip_code,
            zipCode4: @zip_code_suffix
          )
        )
      end

      # @return [Vet360::Models::ValidationAddress] validation address model created from
      #   address validation API response
      def self.build_from_address_suggestion(address_suggestion_hash)
        address_hash = address_suggestion_hash['address']

        new(
          address_line1: address_hash['address_line1'],
          address_line2: address_hash['address_line2'],
          address_line3: address_hash['address_line3'],
          address_type: address_suggestion_hash['address_meta_data']['address_type'].upcase,
          city: address_hash['city'],
          country_name: address_hash['country']['name'],
          country_code_iso3: address_hash['country']['iso3_code'],
          county_code: address_hash.dig('county', 'county_fips_code'),
          county_name: address_hash.dig('county', 'name'),
          state_code: address_hash['state_province']['code'],
          international_postal_code: address_hash['international_postal_code'],
          zip_code: address_hash['zip_code5'],
          zip_code_suffix: address_hash['zip_code4']
        )
      end
    end
  end
end
