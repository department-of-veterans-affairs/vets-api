# frozen_string_literal: true

require 'vet360/response'

module Vet360
  module ContactInformation
    class PersonResponse < Vet360::Response
      attribute :person, Vet360::Models::Person

      attr_reader :response_body

      def initialize(status, response = nil)
        @response_body = response&.body

        super(status, person: Vet360::Models::Person.from_response(@response_body&.dig('bio')))
      end
    end
  end
end
