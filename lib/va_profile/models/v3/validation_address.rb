# frozen_string_literal: true

require_relative 'base_address'
require 'common/hash_helpers'

module VAProfile
  module Models
    module V3
      # Model for addresses sent and received from the VA profile address validation API
      # AddressValidationV is used for ProfileServiceV3 and ContactInformationV2
      class ValidationAddress < V3::BaseAddress
        # Convert a ValidationAddress into a hash that can be sent to the address validation
        # API
        # @return [Hash] hash that is formatted for POSTing to address validation API
        def address_validation_req
          Common::HashHelpers.deep_remove_blanks(
            address: attributes.slice(
              addressLine1: @address_line1,
              addressLine2: @address_line2,
              addressLine3: @address_line3,
              addressPOU: @address_pou,
              cityName: @city,
              zipCode5: @zip_code,
              zipCode4: @zip_code_suffix,
              intPostalCode: @international_postal_code,
              state: {
                stateCode: @state_code,
                stateName: @state_name,

              },
              province: {
                provinceName: @province,
                provinceCode: @province_code,
              },
              country: {
                countryCodeISO2: @country_code_iso2,
                countryCodeISO3: @country_code_iso3,
                countryName: @country_name,
                countryCodeFIPS: @country_code_fips,
              },
              county: {
                countyCode: @county_code,
                countyName: @county_name,
              },
              addressPOU: @address_pou
            )
          )
        end

        # @return [VAProfile::Models::V3::ValidationAddress] validation address model created from
        #   address validation API response
        def self.build_from_address_suggestion(address_suggestion_hash)
          address_hash = address_suggestion_hash['address']
          address_type = address_suggestion_hash['address_meta_data']['address_type'].upcase
          attributes = {
            address_line1: address_hash['address_line1'],
            address_line2: address_hash['address_line2'],
            address_line3: address_hash['address_line3'],
            address_type:,
            city: address_hash['city_name'],
            country_name: address_hash['country']['country_name'],
            country_code_iso3: address_hash['country']['country_code_iso3']
          }.merge(regional_attributes(address_type, address_hash))

          new(attributes)
        end

        def self.regional_attributes(address_type, address_hash)
          if address_type == INTERNATIONAL
            {
              province: address_hash['province']['province_name'],
              int_postal_code: address_hash['int_postal_code']
            }
          else
            {
              state_code: address_hash['state']['state_code'],
              county_code: address_hash['county']['county_code'],
              county_name: address_hash['county']['country_name'],
              zip_code: address_hash['zip_code5'], zip_code_suffix: address_hash['zip_code4']
            }
          end
        end
      end
    end
  end
end

