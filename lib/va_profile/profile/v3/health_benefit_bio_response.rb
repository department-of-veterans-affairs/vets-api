# frozen_string_literal: true

require 'va_profile/response'
require 'va_profile/models/associated_person'
require 'va_profile/models/message'

module VAProfile
  module Profile
    module V3
      class HealthBenefitBioResponse < VAProfile::Response
        attribute :contacts, Array[VAProfile::Models::AssociatedPerson]
        attribute :messages, Array[VAProfile::Models::Message]
        attribute :va_profile_tx_audit_id, String

        def initialize(response)
          contacts = body.dig('profile', 'health_benefit', 'associated_persons')
                         &.select { |p| valid_contact_types.include?(p['contact_type']) }
                         &.sort_by { |p| valid_contact_types.index(p['contact_type']) }
          messages = body['messages']
          va_profile_tx_audit_id = response.response_headers['vaprofiletxauditid']
          super(response.status, { contacts:, messages:, va_profile_tx_audit_id: })
        end

        def metadata
          {
            status:,
            message:,
            va_profile_tx_audit_id:
          }
        end

        private

        def valid_contact_types
          VAProfile::Models::AssociatedPerson::PERSONAL_HEALTH_CARE_CONTACT_TYPES
        end

        def message
          messages&.first&.to_h
        end
      end
    end
  end
end
