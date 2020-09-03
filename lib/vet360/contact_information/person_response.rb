# frozen_string_literal: true

require 'vet360/response'

module Vet360
  module ContactInformation
    class PersonResponse < Vet360::Response
      attribute :person, Vet360::Models::Person

      attr_reader :response_body

      def self.from(raw_response = nil)
        @response_body = raw_response&.body

        new(
          raw_response&.status,
          person: Vet360::Models::Person.build_from(@response_body&.dig('bio'))
        )
      end
    end
  end
end
