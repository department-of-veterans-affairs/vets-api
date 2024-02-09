# frozen_string_literal: true

require_relative 'base'
require 'common/models/attribute_types/iso8601_time'

module VAProfile
  module Models
    class AssociatedPerson < Base
      PRIMARY_NEXT_OF_KIN = 'Primary Next of Kin'
      OTHER_NEXT_OF_KIN = 'Other Next of Kin'
      EMERGENCY_CONTACT = 'Emergency Contact'
      OTHER_EMERGENCY_CONTACT = 'Other emergency contact'

      CONTACT_TYPES = [
        PRIMARY_NEXT_OF_KIN,
        OTHER_NEXT_OF_KIN,
        EMERGENCY_CONTACT,
        OTHER_EMERGENCY_CONTACT
      ].freeze

      attribute :contact_type, String
      attribute :given_name, String
      attribute :middle_name, String
      attribute :family_name, String
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
