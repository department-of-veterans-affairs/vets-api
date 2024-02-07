# frozen_string_literal: true

require 'va_profile/response'
require 'va_profile/models/associated_person'
require 'va_profile/models/message'

module VAProfile::Profile::V3
  class HealthBenefitBioResponse < VAProfile::Response
    attribute :contacts, Array[VAProfile::Models::AssociatedPerson]
    attribute :messages, Array[VAProfile::Models::Message]

    def initialize(status, data)
      super(status)
      self.contacts = data[:contacts]
      self.messages = data[:messages]
    end

    class << self
      def from(response)
        contacts = response
                   .body
                   .dig('profile', 'healthBenefit', 'associatedPersons')
                   &.map { |p| VAProfile::Models::AssociatedPerson.build_from(p) }
        messages = response
                   .body['messages']
                   &.map { |m| VAProfile::Models::Message.build_from(m) }
        new(response.status, { contacts:, messages: })
      end
    end
  end
end
