# frozen_string_literal: true

require_relative 'base'
require 'common/models/attribute_types/iso8601_time'
require 'va_profile/concerns/defaultable'
require 'va_profile/concerns/expirable'

module VAProfile
  module Models
    class BaseAddress < Base
      include VAProfile::Concerns::Defaultable
      include VAProfile::Concerns::Expirable

      VALID_ALPHA_REGEX = /[a-zA-Z ]+/
      VALID_NUMERIC_REGEX = /[0-9]+/
      ADDRESS_FIELD_LIMIT = 35
      RESIDENCE = 'RESIDENCE/CHOICE'
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
      attribute :geocode_date, Common::ISO8601Time
      attribute :geocode_precision, Float
      attribute :id, Integer
      attribute :international_postal_code, String
      attribute :latitude, Float
      attribute :longitude, Float
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

      validate :ascii_only
      validates(:address_line1, presence: true)
      validates(:city, presence: true)
      validates(:country_code_iso3, length: { maximum: 3 })
      validates(:international_postal_code, length: { maximum: 35 })
      validates(:zip_code, length: { maximum: 5 })

      validates(
        :city,
        :province,
        length: { maximum: 100 }
      )

      validates(
        :address_line1,
        :address_line2,
        :address_line3,
        length: { maximum: ADDRESS_FIELD_LIMIT }
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

      validates(:country_code_iso3, presence: true)

      with_options if: proc { |a| [DOMESTIC, MILITARY].include?(a.address_type) } do
        validates :state_code, presence: true
        validates :zip_code, presence: true
        validates :province, absence: true
      end

      with_options if: proc { |a| a.address_type == INTERNATIONAL } do
        validates :state_code, absence: true
        validates :zip_code, absence: true
        validates :zip_code_suffix, absence: true
        validates :county_name, absence: true
        validates :county_code, absence: true
      end

      def ascii_only
        address = [
          address_line1,
          address_line2,
          address_line3,
          city,
          province,
          international_postal_code
        ].join

        errors.add(:address, 'must contain ASCII characters only') unless address.ascii_only?
      end

      def zip_plus_four
        return if zip_code.blank?

        [zip_code, zip_code_suffix].compact.join('-')
      end
    end
  end
end
