# frozen_string_literal: true

require 'va_profile/response'
require 'va_profile/models/associated_person'
require 'va_profile/models/message'

module VAProfile::Profile::V3
  class HealthBenefitBioResponse < VAProfile::Response
    attribute :associated_persons, Array[VAProfile::Models::AssociatedPerson]
    attribute :messages, Array[VAProfile::Models::Message]
    attribute :body, String

    def initialize(status_code, body, data)
      super(status_code)
      self.body = body
      self.associated_persons = data[:associated_persons]
      self.messages = data[:messages]
    end

    class << self
      def from(response)
        associated_persons = response
                             .body
                             .dig('profile', 'healthBenefit', 'associatedPersons')
                             &.map { |p| VAProfile::Models::AssociatedPerson.build_from(p) }
        messages = response
                   .body['messages']
                   &.map { |m| VAProfile::Models::Message.build_from(m) }
        new(response.status, response.body, { associated_persons:, messages: })
      end
    end
  end
end
