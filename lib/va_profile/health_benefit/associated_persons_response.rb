# frozen_string_literal: true

require 'va_profile/response'
require 'va_profile/models/associated_person'
require 'va_profile/models/message'

module VAProfile
  module HealthBenefit
    class AssociatedPersonsResponse < VAProfile::Response
      attribute :associated_persons, Array[VAProfile::Models::AssociatedPerson]
      attribute :messages, Array[VAProfile::Models::Message]

      def initialize(response)
        resource = JSON.parse(response.body)
        associated_persons = resource['associated_persons']
        messages = resource['messages']
        super(response.status, { associated_persons:, messages: })
      end
    end
  end
end
