# frozen_string_literal: true

require 'va_profile/response'
require 'va_profile/models/associated_person'
require 'va_profile/models/message'

module VAProfile::Profile::V3
  class HealthBenefitBioResponse < VAProfile::Response
    attr_reader :body

    attribute :contacts, Array[VAProfile::Models::AssociatedPerson]
    attribute :messages, Array[VAProfile::Models::Message]

    def initialize(response)
      @body = response.body
      contacts = body.dig('profile', 'health_benefit', 'associated_persons')
                     &.sort_by { |p| VAProfile::Models::AssociatedPerson::CONTACT_TYPES.index(p['contact_type']) }
      messages = body['messages']
      super(response.status, { contacts:, messages: })
    end

    def metadata
      { status:, messages: }
    end
  end
end
