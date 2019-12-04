# frozen_string_literal: true

module Vet360
  module Models
    class BaseAddress < Base
      include Vet360::Concerns::Defaultable

      VALID_ALPHA_REGEX = /[a-zA-Z ]+/.freeze
      VALID_NUMERIC_REGEX = /[0-9]+/.freeze

      RESIDENCE      = 'RESIDENCE/CHOICE'
      CORRESPONDENCE = 'CORRESPONDENCE'
      ADDRESS_POUS   = [RESIDENCE, CORRESPONDENCE].freeze
      DOMESTIC       = 'DOMESTIC'
      INTERNATIONAL  = 'INTERNATIONAL'
      MILITARY       = 'OVERSEAS MILITARY'
      ADDRESS_TYPES  = [DOMESTIC, INTERNATIONAL, MILITARY].freeze

      attribute :address_line1, String
      attribute :address_line2, String
      attribute :address_line3, String
      attribute :address_pou, String # purpose of use
      attribute :address_type, String
      attribute :city, String
      attribute :country_name, String
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
      attribute :source_system_user, String
      attribute :state_code, String
      attribute :transaction_id, String
      attribute :updated_at, Common::ISO8601Time
      attribute :validation_key, Integer
      attribute :vet360_id, String
      attribute :zip_code, String
      attribute :zip_code_suffix, String

      validates(:address_line1, presence: true)
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
        :country_name,
        length: { maximum: 35 },
        allow_blank: true,
        format: { with: VALID_ALPHA_REGEX }
      )

      validates(
        :state_code,
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

      with_options if: proc { |a| a.address_type == DOMESTIC } do
        validates :state_code, presence: true
        validates :zip_code, presence: true
        validates :province, absence: true
      end

      with_options if: proc { |a| a.address_type == INTERNATIONAL } do
        validates :international_postal_code, presence: true
        validates :state_code, absence: true
        validates :zip_code, absence: true
        validates :zip_code_suffix, absence: true
        validates :county_name, absence: true
        validates :county_code, absence: true
      end

      with_options if: proc { |a| a.address_type == MILITARY } do
        validates :state_code, presence: true
        validates :zip_code, presence: true
        validates :province, absence: true
      end

      def zip_plus_four
        return if zip_code.blank?

        [zip_code, zip_code_suffix].compact.join('-')
      end
    end
  end
end
