# frozen_string_literal: true

require_relative 'base_address'

module Vet360
  module Models
    class Address < BaseAddress
      validates(:source_date, presence: true)

      # Converts a decoded JSON response from Vet360 to an instance of the Address model
      # @param body [Hash] the decoded response body from Vet360
      # @return [Vet360::Models::Address] the model built from the response body
      # rubocop:disable Metrics/MethodLength
      def in_json
        address_attributes = {
          addressId: @id,
          addressLine1: @address_line1,
          addressLine2: @address_line2,
          addressLine3: @address_line3,
          addressPOU: @address_pou,
          addressType: @address_type,
          cityName: @city,
          countryCodeISO2: @country_code_iso2,
          countryCodeISO3: @country_code_iso3,
          countryName: @country_name,
          county: {
            countyCode: @county_code,
            countyName: @county_name
          },
          intPostalCode: @international_postal_code,
          provinceName: @province,
          stateCode: @state_code,
          zipCode5: @zip_code,
          zipCode4: @zip_code_suffix,
          originatingSourceSystem: SOURCE_SYSTEM,
          sourceSystemUser: @source_system_user,
          sourceDate: @source_date,
          vet360Id: @vet360_id,
          effectiveStartDate: @effective_start_date,
          effectiveEndDate: @effective_end_date
        }

        if @validation_key.present?
          address_attributes[:validationKey] = @validation_key
          address_attributes[:overrideIndicator] = true
        end

        {
          bio: address_attributes
        }.to_json
      end
      # rubocop:enable Metrics/MethodLength

      # Converts a decoded JSON response from Vet360 to an instance of the Address model
      # @param body [Hash] the decoded response body from Vet360
      # @return [Vet360::Models::Address] the model built from the response body
      # rubocop:disable Metrics/MethodLength
      def self.build_from(body)
        Vet360::Models::Address.new(
          address_line1: body['address_line1'],
          address_line2: body['address_line2'],
          address_line3: body['address_line3'],
          address_pou: body['address_pou'],
          address_type: body['address_type'].upcase,
          city: body['city_name'],
          country_name: body['country_name'],
          country_code_iso2: body['country_code_iso2'],
          country_code_iso3: body['country_code_iso3'],
          county_code: body.dig('county', 'county_code'),
          county_name: body.dig('county', 'county_name'),
          created_at: body['create_date'],
          effective_end_date: body['effective_end_date'],
          effective_start_date: body['effective_start_date'],
          id: body['address_id'],
          international_postal_code: body['int_postal_code'],
          province: body['province_name'],
          source_date: body['source_date'],
          state_code: body['state_code'],
          transaction_id: body['tx_audit_id'],
          updated_at: body['update_date'],
          vet360_id: body['vet360_id'],
          zip_code: body['zip_code5'],
          zip_code_suffix: body['zip_code4']
        )
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
