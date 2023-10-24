# frozen_string_literal: true

require_relative 'base'
require 'common/models/attribute_types/iso8601_time'

module VAProfile
  module Models
    class AssociatedPerson < Base
      # attributes from OpenAPI/Swagger documentation
      attribute :create_date, Common::ISO8601Time # read-only
      attribute :update_date, Common::ISO8601Time # read-only
      attribute :tx_audit_id, String # read-only
      attribute :source_system, String # read-only
      attribute :originating_source_system, String
      attribute :source_system_user, String

      # attributes shared with Health Benefit BIO Graph
      attribute :contact_type, String
      attribute :prefix, String
      attribute :given_name, String
      attribute :middle_name, String
      attribute :family_name, String
      attribute :suffix, String
      attribute :relationship, String
      attribute :address_line1, String
      attribute :address_line2, String
      attribute :address_line3, String
      attribute :city, String
      attribute :state, String
      attribute :county, String
      attribute :zip_code, String
      attribute :zip_plus4, String
      attribute :postal_code, String
      attribute :province_code, String
      attribute :country, String
      attribute :primary_phone, String
      attribute :alternate_phone, String
      attribute :effective_end_date, Common::ISO8601Time

      PRIMARY_NEXT_OF_KIN = 'Primary Next of Kin'
      OTHER_NEXT_OF_KIN = 'Other Next of Kin'
      EMERGENCY_CONTACT = 'Emergency Contact'
      OTHER_EMERGENCY_CONTACT = 'Other emergency contact'

      NOK_TYPES = [PRIMARY_NEXT_OF_KIN, OTHER_NEXT_OF_KIN].freeze
      EC_TYPES = [EMERGENCY_CONTACT, OTHER_EMERGENCY_CONTACT].freeze

      CONTACT_TYPES = [
        PRIMARY_NEXT_OF_KIN,
        OTHER_NEXT_OF_KIN,
        EMERGENCY_CONTACT,
        OTHER_EMERGENCY_CONTACT
      ].freeze

      class << self
        # Translate a VA Profile Health Benefit API response.body.associated_persons
        #   entry to an AssociatedPerson model
        # @param json [Hash] response.body['associated_persons'] entry
        # @return [VAProfile::Models::AssociatedPerson] model created from json response
        # rubocop:disable Metrics/MethodLength
        def build_from(json)
          new(
            create_date: json['create_date'],
            udpate_date: json['update_date'],
            tx_audit_id: json['tx_audit_id'],
            source_system: json['source_system'],
            originating_source_system: json['originating_source_system'],
            source_system_user: json['source_system_user'],
            contact_type: json['contact_type'],
            prefix: json['prefix'],
            given_name: json['given_name'],
            middle_name: json['middle_name'],
            family_name: json['family_name'],
            suffix: json['suffix'],
            relationship: json['relationship'],
            address_line1: json['address_line1'],
            address_line2: json['address_line2'],
            address_line3: json['address_line3'],
            city: json['city'],
            state: json['state'],
            county: json['county'],
            zip_code: json['zip_code'],
            zip_plus4: json['zip_plus4'],
            postal_code: json['postal_code'],
            province_code: json['province_code'],
            country: json['country'],
            primary_phone: json['primary_phone'],
            alternate_phone: json['alternate_phone'],
            effective_end_date: json['effective_end_date']
          )
        end
        # rubocop:enable Metrics/MethodLength
      end
    end
  end
end
