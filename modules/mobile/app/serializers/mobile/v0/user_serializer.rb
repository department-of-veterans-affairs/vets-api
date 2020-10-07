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

      SERVICE_DICTIONARY = {
        appeals: :appeals,
        appointments: :vaos,
        claims: :evss,
        directDepositBenefits: :evss,
        lettersAndDocuments: :evss,
        militaryServiceHistory: :emis,
        userProfileUpdate: :vet360
      }.freeze

      def self.filter_address(address)
        address&.to_h&.slice(*ADDRESS_KEYS)
      end

      attribute :profile do |user|
        {
          first_name: user.first_name,
          middle_name: user.middle_name,
          last_name: user.last_name,
          email: user.email,
          residential_address: filter_address(user.vet360_contact_info&.residential_address),
          mailing_address: filter_address(user.vet360_contact_info&.mailing_address)
        }
      end

      attribute :authorized_services do |user|
        SERVICE_DICTIONARY.filter { |_k, v| user.authorize v, :access? }.keys
      end
    end
  end
end
