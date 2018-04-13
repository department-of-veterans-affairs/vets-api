# frozen_string_literal: true

module Vet360
  module Models
    class Address < Base
      attribute :address_line_1, String
      attribute :address_line_2, String
      attribute :address_line_3, String
      attribute :address_pou, String # purpose of use
      attribute :address_type, String
      attribute :city, String
      attribute :country, String
      attribute :country_code_iso2, String
      attribute :country_code_iso3, String
      attribute :county_code, String
      attribute :county_name, String
      attribute :created_at, Common::ISO8601Time
      attribute :id, Integer
      attribute :international_postal_code, String
      attribute :source_date, Common::ISO8601Time
      attribute :state_abbr, String
      attribute :transaction_id, String
      attribute :updated_at, Common::ISO8601Time
      attribute :zip_code, String
      attribute :zip_code_suffix, String

      validates :source_date, presence: true

      # rubocop:disable Metrics/MethodLength
      def self.from_response(body)
        Vet360::Models::Address.new(
          address_line_1: body['address_line_1'],
          address_line_2: body['address_line_2'],
          address_line_3: body['address_line_3'],
          address_pou: body['address_pou'],
          address_type: body['address_type'],
          city: body['city_name'],
          country: body['country_name'],
          country_code_iso2: body['country_code_iso2'],
          country_code_iso3: body['country_code_iso3'],
          county_code: body.dig('county', 'county_code'),
          county_name: body.dig('county', 'county_name'),
          created_at: body['create_date'],
          id: body['address_id'],
          international_postal_code: body['int_postal_code'],
          source_date: body['source_date'],
          state_abbr: body['state_code'],
          transaction_id: body['tx_audit_id'],
          updated_at: body['updateDate'],
          zip_code: body['zip_code5'],
          zip_code_suffix: body['zip_code4']
        )
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
