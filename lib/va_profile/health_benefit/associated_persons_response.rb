# frozen_string_literal: true

require 'va_profile/response'

module VAProfile
  module HealthBenefit
    class AssociatedPersonsResponse < VAProfile::Response
      attribute :associated_persons, Array[VAProfile::Models::AssociatedPerson]
      attribute :messages, Array[VAProfile::Models::Message]

      def initialize(status_code, data)
        super(status_code)
        self.associated_persons = data[:associated_persons]
        self.messages = data[:messages]
      end

      class << self
        def from(response)
          status_code = response.status
          json = JSON.parse(response.body)
          associated_persons = json['associated_persons']
            &.map { |p| VAProfile::Models::AssociatedPerson.build_from(p) }
          messages = json['messages']
            &.map { |m| VAProfile::Models::Message.build_from(m) }
          new(status_code, { associated_persons:, messages: })
        end
      end
    end
  end
end
