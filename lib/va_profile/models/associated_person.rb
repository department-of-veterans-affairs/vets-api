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

      class << self
        # Translate a VA Profile Health Benefit BIO associated_persons record
        #   to an AssociatedPerson model
        # @param json [Hash] associated_persons record
        # @return [VAProfile::Models::AssociatedPerson] model created from json response
        def build_from(json)
          new(
            contact_type: json['contactType'],
            given_name: json['givenName'],
            middle_name: json['middleName'],
            family_name: json['familyName'],
            relationship: json['relationship'],
            address_line1: json['addressLine1'],
            address_line2: json['addressLine2'],
            address_line3: json['addressLine3'],
            city: json['city'],
            state: json['state'],
            zip_code: json['zipCode'],
            primary_phone: json['primaryPhone']
          )
        end
      end
    end
  end
end
