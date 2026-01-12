# frozen_string_literal: true

require 'va_profile/response'
require 'va_profile/models/associated_person'
require 'va_profile/models/message'

module VAProfile
  module Profile
    module V3
      class HealthBenefitBioResponse < VAProfile::Response
        attribute :code, String
        attribute :contacts, VAProfile::Models::AssociatedPerson, array: true, default: []
        attribute :messages, VAProfile::Models::Message, array: true
        attribute :va_profile_tx_audit_id, String

        def initialize(response)
          body = response&.body
          @contact_types = body.dig('profile', 'health_benefit', 'associated_persons')&.pluck('contact_type')
          contacts = body.dig('profile', 'health_benefit', 'associated_persons')
                         &.select { |p| valid_contact_types.include?(p['contact_type']) }
                         &.sort_by { |p| valid_contact_types.index(p['contact_type']) }
          messages = body['messages']
          code = messages&.first&.dig('code')
          va_profile_tx_audit_id = response.response_headers['vaprofiletxauditid']
          super(response.status, { code:, contacts:, messages:, va_profile_tx_audit_id: })
        end

        def meta
          {
            code:,
            status:,
            message:,
            contact_types: @contact_types,
            contact_count: contacts&.count || 0,
            va_profile_tx_audit_id:
          }
        end

        def server_error?
          status >= 500
        end

        private

        def valid_contact_types
          VAProfile::Models::AssociatedPerson::PERSONAL_HEALTH_CARE_CONTACT_TYPES
        end

        def message
          m = messages&.first
          return '' unless m

          "#{m.code} #{m.key} #{m.text}"
        end
      end
    end
  end
end
