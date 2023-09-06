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

      CONTACT_TYPES = [
        PRIMARY_NEXT_OF_KIN,
        OTHER_NEXT_OF_KIN,
        EMERGENCY_CONTACT,
        OTHER_EMERGENCY_CONTACT
      ].freeze

      # validation maximums from OpenAPI/Swagger docs
      # required fields: given_name, family_name, and primary_phone
      validates :contact_type, inclusion: { in: CONTACT_TYPES }
      validates :prefix, length: { maximum: 12 }
      validates :given_name, length: { maximum: 30 }, presence: true
      validates :middle_name, length: { maximum: 30 }
      validates :family_name, length: { maximum: 40 }, presence: true
      validates :suffix, length: { maximum: 12 }
      validates :relationship, length: { maximum: 250 }
      validates :address_line1, length: { maximum: 100 }
      validates :address_line2, length: { maximum: 100 }
      validates :address_line3, length: { maximum: 100 }
      validates :city, length: { maximum: 60 }
      validates :state, length: { maximum: 50 }
      validates :county, length: { maximum: 50 }
      validates :zip_code, length: { maximum: 20 }
      validates :zip_plus4, length: { maximum: 10 }
      validates :postal_code, length: { maximum: 50 }
      validates :province_code, length: { maximum: 50 }
      validates :country, length: { maximum: 20 }
      validates :primary_phone, length: { maximum: 30 }, presence: true
      validates :alternate_phone, length: { maximum: 30 }

      with_options if: ->(o) { [PRIMARY_NEXT_OF_KIN, OTHER_NEXT_OF_KIN].include?(o.contact_type) } do
        validates :relationship, presence: true
        validates :address_line1, presence: true
        # ...
      end

      # Prepare AssociatedPerson data for POSTing to VA Profile Health Benefit Service v1
      # @return [String] JSON string representing an AssociatedPerson record
      # rubocop:disable Metrics/MethodLength
      def in_json
        {
          associatedPersons: [{
            sourceDate: Time.zone.now.iso8601,
            originatingSourceSystem: SOURCE_SYSTEM,
            sourceSystemUser: nil, # user.icn
            contactType: @contact_type,
            prefix: @prefix,
            givenName: @given_name,
            middleName: @middle_name,
            familyName: @family_name,
            suffix: @suffix,
            relationship: @relationship,
            addressLine1: @address_line1,
            addressLine2: @address_line2,
            addressLine3: @address_line3,
            city: @city,
            state: @state,
            county: @county,
            zipCode: @zip_code,
            zipPlus4: @zip_plus4,
            postalCode: @postal_code,
            provinceCode: @province_code,
            country: @country,
            primaryPhone: @primary_phone,
            alternatePhone: @alternate_phone,
            effectiveEndDate: @effective_end_date
          }]
        }.to_json
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
