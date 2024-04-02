# frozen_string_literal: true

require 'va_profile/response'
require 'va_profile/models/associated_person'
require 'va_profile/models/message'

module VAProfile
  module Profile
    module V3
      class HealthBenefitBioResponse < VAProfile::Response
        attr_reader(
          :body,
          :va_profile_tx_audit_id
        )

        attribute :contacts, Array[VAProfile::Models::AssociatedPerson]
        attribute :messages, Array[VAProfile::Models::Message]

        def initialize(response)
          @body = response.body
          @va_profile_tx_audit_id = response.response_headers['vaprofiletxauditid']

          contacts = body.dig('profile', 'health_benefit', 'associated_persons')
                         &.select { |p| valid_contact_types.include?(p['contact_type']) }
                         &.sort_by { |p| valid_contact_types.index(p['contact_type']) }
          messages = body['messages']
          super(response.status, { contacts:, messages: })
        end

        def metadata
          {
            status:,
            messages:,
            va_profile_tx_audit_id:
          }
        end

        private

        def valid_contact_types
          [
            VAProfile::Models::AssociatedPerson::EMERGENCY_CONTACT,
            VAProfile::Models::AssociatedPerson::OTHER_EMERGENCY_CONTACT,
            VAProfile::Models::AssociatedPerson::PRIMARY_NEXT_OF_KIN,
            VAProfile::Models::AssociatedPerson::OTHER_NEXT_OF_KIN
          ]
        end
      end
    end
  end
end
