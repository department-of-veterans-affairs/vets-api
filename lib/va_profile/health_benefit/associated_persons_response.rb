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
        associated_persons = response.body['associated_persons']
        messages = response.body['messages']
        super(response.status, { associated_persons:, messages: })
      end
    end
  end
end
