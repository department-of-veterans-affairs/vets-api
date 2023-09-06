# frozen_string_literal: true

require 'va_profile/response'

module VAProfile
  module HealthBenefit
    class AssociatedPersonsResponse < VAProfile::Response
      class << self
        def from(response)
          status_code = response.status
          associated_persons = response
            .body['associated_persons']
            .map(&:VAProfile::Models::AssociatedPerson.build_from)
          messages = response
            .body['messages']
            .map(&:VAProfile::Models::Message.build_from)
          new(status_code, associated_persons, messages)
        end
      end

      attribute :associated_persons, Array[VAProfile::Models::AssociatedPerson]
      attribute :messages, Array[VAProfile::Models::Message]
    end
  end
end
