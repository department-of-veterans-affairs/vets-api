# frozen_string_literal: true

require_relative 'base'

class TitleCaseString < Virtus::Attribute
  def coerce(value)
    value&.downcase&.titleize
  end
end

module VAProfile
  module Models
    class AssociatedPerson < Base
      EMERGENCY_CONTACT = 'Emergency Contact'
      OTHER_EMERGENCY_CONTACT = 'Other emergency contact'
      PRIMARY_NEXT_OF_KIN = 'Primary Next of Kin'
      OTHER_NEXT_OF_KIN = 'Other Next of Kin'

      CONTACT_TYPES = [
        EMERGENCY_CONTACT,
        OTHER_EMERGENCY_CONTACT,
        PRIMARY_NEXT_OF_KIN,
        OTHER_NEXT_OF_KIN
      ].freeze

      attribute :contact_type, String
      attribute :given_name, TitleCaseString
      attribute :middle_name, TitleCaseString
      attribute :family_name, TitleCaseString
      attribute :relationship, TitleCaseString
      attribute :address_line1, String
      attribute :address_line2, String
      attribute :address_line3, String
      attribute :city, TitleCaseString
      attribute :state, String
      attribute :zip_code, String
      attribute :primary_phone, String
    end
  end
end
