# frozen_string_literal: true

module Vet360
  module Models
    class Address < Base
      include Vet360::Concerns::Defaultable

      VALID_ALPHA_REGEX = /[a-zA-Z ]+/
      VALID_NUMERIC_REGEX = /[0-9]+/

      RESIDENCE      = 'RESIDENCE/CHOICE'
      CORRESPONDENCE = 'CORRESPONDENCE'
      ADDRESS_POUS   = [RESIDENCE, CORRESPONDENCE].freeze
      DOMESTIC       = 'domestic'
      INTERNATIONAL  = 'international'
      MILITARY       = 'military overseas'
      ADDRESS_TYPES  = [DOMESTIC, INTERNATIONAL, MILITARY].freeze

      attribute :address_line1, String
      attribute :address_line2, String
      attribute :address_line3, String
      attribute :address_pou, String # purpose of use
      attribute :address_type, String
      attribute :city, String
      attribute :country, String
      attribute :country_code_iso2, String
      attribute :country_code_iso3, String
      attribute :country_code_fips, String
      attribute :county_code, String
      attribute :county_name, String
      attribute :created_at, Common::ISO8601Time
      attribute :effective_end_date, Common::ISO8601Time
      attribute :effective_start_date, Common::ISO8601Time
      attribute :id, Integer
      attribute :international_postal_code, String
      attribute :province, String
      attribute :source_date, Common::ISO8601Time
      attribute :state_abbr, String
      attribute :transaction_id, String
      attribute :updated_at, Common::ISO8601Time
      attribute :vet360_id, String
      attribute :zip_code, String
      attribute :zip_code_suffix, String

      validates(:address_line1, presence: true)
      validates(:source_date, presence: true)
      validates(:city, presence: true)
      validates(:country_code_iso3, length: { maximum: 3 })
      validates(:international_postal_code, length: { maximum: 35 })
      validates(:zip_code, length: { maximum: 5 })

      validates(
        :address_line1,
        :address_line2,
        :address_line3,
        :city,
        :province,
        length: { maximum: 100 }
      )

      validates(
        :country,
        presence: true,
        length: { maximum: 35 },
        format: { with: VALID_ALPHA_REGEX }
      )

      validates(
        :state_abbr,
        length: { maximum: 2, minimum: 2 },
        format: { with: VALID_ALPHA_REGEX },
        allow_blank: true
      )

      validates(
        :zip_code_suffix,
        length: { maximum: 4 },
        format: { with: VALID_NUMERIC_REGEX },
        allow_blank: true
      )

      validates(
        :address_pou,
        presence: true,
        inclusion: { in: ADDRESS_POUS }
      )

      validates(
        :address_type,
        presence: true,
        inclusion: { in: ADDRESS_TYPES }
      )

      with_options if: proc { |a| a.address_type == DOMESTIC } do |address|
        address.validates :state_abbr, presence: true
        address.validates :zip_code, presence: true
        address.validates :province, absence: true
      end

      with_options if: proc { |a| a.address_type == INTERNATIONAL } do |address|
        address.validates :international_postal_code, presence: true
        address.validates :state_abbr, absence: true
        address.validates :zip_code, absence: true
        address.validates :zip_code_suffix, absence: true
        address.validates :county_name, absence: true
        address.validates :county_code, absence: true
      end

      with_options if: proc { |a| a.address_type == MILITARY } do |address|
        address.validates :state_abbr, presence: true
        address.validates :zip_code, presence: true
        address.validates :province, absence: true
      end

      # Converts a decoded JSON response from Vet360 to an instance of the Address model
      # @param body [Hash] the decoded response body from Vet360
      # @return [Vet360::Models::Address] the model built from the response body
      # rubocop:disable Metrics/MethodLength
      def in_json
        {
          bio: {
            addressId: @id,
            addressLine1: @address_line1,
            addressLine2: @address_line2,
            addressLine3: @address_line3,
            addressPOU: @address_pou,
            addressType: @address_type,
            cityName: @city,
            countryCodeISO2: @country_code_iso2,
            countryCodeISO3: @country_code_iso3,
            countryName: @country,
            county: {
              countyCode: @county_code,
              countyName: @county_name
            },
            intPostalCode: @international_postal_code,
            provinceName: @province,
            stateCode: @state_abbr,
            zipCode4: @zip_code,
            zipCode5: @zip_code_suffix,
            originatingSourceSystem: SOURCE_SYSTEM,
            sourceDate: @source_date,
            vet360Id: @vet360_id,
            effectiveStartDate: @effective_start_date,
            effectiveEndDate: @effective_end_date
          }
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
          address_type: body['address_type'],
          city: body['city_name'],
          country: body['country_name'],
          country_code_iso2: body['country_code_iso2'],
          country_code_iso3: body['country_code_iso3'],
          county_code: body.dig('county', 'county_code'),
          county_name: body.dig('county', 'county_name'),
          created_at: body['create_date'],
          effective_end_date: body['effective_end_date'],
          effective_start_date: body['effective_start_date'],
          id: body['address_id'],
          international_postal_code: body['int_postal_code'],
          source_date: body['source_date'],
          state_abbr: body['state_code'],
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
