# frozen_string_literal: true

require_relative 'base_address'

module VAProfile
  module Models
    module V3
      class Address < V3::BaseAddress
        attribute :bad_address, Boolean

        validates(:source_date, presence: true)

        # Converts a decoded JSON response from VAProfile to an instance of the Address model
        # @param body [Hash] the decoded response body from VAProfile
        # @return [VAProfile::Models::V3::Address] the model built from the response body
        # rubocop:disable Metrics/MethodLength
        # in_json_v2 will replace in_json when Contact Information V1 Service has depreciated
        def in_json_v2
          address_attributes = {
            addressId: @id,
            addressLine1: @address_line1,
            addressLine2: @address_line2,
            addressLine3: @address_line3,
            addressPOU: @address_pou,
            addressType: @address_type.titleize,
            cityName: @city,
            country: {
              countryName: @country_name,
              countryCodeFIPS: @country_code_fips,
              countryCodeISO2: @country_code_iso2,
              countryCodeISO3: @country_code_iso3
            },
            county: {
              countyCode: @county_code,
              countyName: @county_name
            },
            province: {
              provinceName: @province,
              provinceCode: @province_code
            },
            state: {
              stateName: @state_name,
              stateCode: @state_code
            },
            intPostalCode: @international_postal_code,
            zipCode5: @zip_code,
            zipCode4: @zip_code_suffix,
            originatingSourceSystem: SOURCE_SYSTEM,
            sourceSystemUser: @source_system_user,
            sourceDate: @source_date,
            effectiveStartDate: @effective_start_date,
            effectiveEndDate: @effective_end_date
          }

          address_attributes[:overrideValidationKey] = @override_validation_key if @override_validation_key.present?

          address_attributes[:badAddress] = false if correspondence?

          {
            bio: address_attributes
          }.to_json
        end
        # rubocop:enable Metrics/MethodLength

        # Converts a decoded JSON response from VAProfile to an instance of the Address model
        # @param body [Hash] the decoded response body from VAProfile
        # @return [VAProfile::Models::V3::Address] the model built from the response body
        # rubocop:disable Metrics/MethodLength
        def self.build_from(body)
          VAProfile::Models::V3::Address.new(
            address_line1: body['address_line1'],
            address_line2: body['address_line2'],
            address_line3: body['address_line3'],
            address_pou: body['address_pou'],
            address_type: body['address_type'].upcase,
            bad_address: body['bad_address'],
            city: body['city_name'],
            country_name: body.dig('country', 'country_name'),
            country_code_iso2: body.dig('country', 'country_code_iso2'),
            country_code_iso3: body.dig('country', 'country_code_iso3'),
            fips_code: body.dig('country', 'country_code_fips'),
            county_code: body.dig('county', 'county_code'),
            county_name: body.dig('county', 'county_name'),
            created_at: body['create_date'],
            effective_end_date: body['effective_end_date'],
            effective_start_date: body['effective_start_date'],
            geocode_date: body['geocode_date'],
            geocode_precision: body['geocode_precision'],
            id: body['address_id'],
            international_postal_code: body['int_postal_code'],
            latitude: body['latitude'],
            longitude: body['longitude'],
            province: body['province_name'],
            source_date: body['source_date'],
            state_code: body.dig('state', 'state_code'),
            state_name: body.dig('state', 'state_name'),
            transaction_id: body['tx_audit_id'],
            updated_at: body['update_date'],
            vet360_id: body['vet360_id'] || body['va_profile_id'],
            va_profile_id: body['va_profile_id'] || body['vet360_id'],
            zip_code: body['zip_code5'],
            zip_code_suffix: body['zip_code4']
          )
        end
        # rubocop:enable Metrics/MethodLength

        def correspondence?
          @address_pou == VAProfile::Models::V3::Address::CORRESPONDENCE
        end
      end
    end
  end
end
