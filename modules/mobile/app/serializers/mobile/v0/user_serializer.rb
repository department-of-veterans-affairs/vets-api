# frozen_string_literal: true

require 'fast_jsonapi'

module Mobile
  module V0
    class UserSerializer
      include FastJsonapi::ObjectSerializer

      ADDRESS_KEYS = %i[
        address_line1
        address_line2
        address_line3
        address_pou
        address_type
        city
        country_code
        international_postal_code
        province
        state_code
        zip_code
        zip_code_suffix
      ].freeze

      PHONE_KEYS = %i[
        id
        area_code
        country_code
        extension
        phone_number
        phone_type
      ].freeze

      SERVICE_DICTIONARY = {
        appeals: :appeals,
        appointments: :vaos,
        claims: :evss,
        directDepositBenefits: :evss,
        lettersAndDocuments: :evss,
        militaryServiceHistory: :emis,
        userProfileUpdate: :vet360
      }.freeze

      def self.filter_keys(value, keys)
        value&.to_h&.slice(*keys)
      end

      attribute :profile do |user|
        {
          first_name: user.first_name,
          middle_name: user.middle_name,
          last_name: user.last_name,
          email: user.email,
          birth_date: user.birth_date.nil? ? nil : Date.parse(user.birth_date).iso8601,
          gender: user.gender,
          residential_address: filter_keys(user.vet360_contact_info&.residential_address, ADDRESS_KEYS),
          mailing_address: filter_keys(user.vet360_contact_info&.mailing_address, ADDRESS_KEYS),
          home_phone_number: filter_keys(user.vet360_contact_info&.home_phone, PHONE_KEYS),
          mobile_phone_number: filter_keys(user.vet360_contact_info&.work_phone, PHONE_KEYS),
          work_phone_number: filter_keys(user.vet360_contact_info&.mobile_phone, PHONE_KEYS),
          fax_number: filter_keys(user.vet360_contact_info&.fax_number, PHONE_KEYS)
        }
      end

      attribute :authorized_services do |user|
        SERVICE_DICTIONARY.filter { |_k, v| user.authorize v, :access? }.keys
      end
    end
  end
end
