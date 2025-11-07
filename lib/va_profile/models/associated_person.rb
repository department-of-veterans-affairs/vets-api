# frozen_string_literal: true

require_relative 'base'

module VAProfile
  module Models
    class AssociatedPerson < Base
      EMERGENCY_CONTACT = 'Emergency Contact'
      OTHER_EMERGENCY_CONTACT = 'Other emergency contact'
      PRIMARY_NEXT_OF_KIN = 'Primary Next of Kin'
      OTHER_NEXT_OF_KIN = 'Other Next of Kin'
      DESIGNEE = 'Designee'
      POWER_OF_ATTORNEY = 'Power of Attorney'

      PERSONAL_HEALTH_CARE_CONTACT_TYPES = [
        EMERGENCY_CONTACT,
        OTHER_EMERGENCY_CONTACT,
        PRIMARY_NEXT_OF_KIN,
        OTHER_NEXT_OF_KIN
      ].freeze

      CONTACT_TYPES = [
        *PERSONAL_HEALTH_CARE_CONTACT_TYPES,
        DESIGNEE,
        POWER_OF_ATTORNEY
      ].freeze

      attribute :contact_type, String
      attribute :given_name, Vets::Type::TitlecaseString
      attribute :middle_name, Vets::Type::TitlecaseString
      attribute :family_name, Vets::Type::TitlecaseString
      attribute :relationship, String
      attribute :address_line1, String
      attribute :address_line2, String
      attribute :address_line3, String
      attribute :city, String
      attribute :state, String
      attribute :zip_code, String
      attribute :primary_phone, String
    end
  end
end
