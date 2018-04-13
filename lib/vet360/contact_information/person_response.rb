# frozen_string_literal: true

require 'vet360/response'

module Vet360
  module ContactInformation
    class PersonResponse < Vet360::Response
      attribute :person, Vet360::Models::Person

      attr_reader :bio

      def initialize(status, response = nil)
        # TODO: how do we want to customize the response
        @bio = response&.body&.dig('bio')
        super(status, person: Vet360::Models::Person.from_response(@bio))
      end
    end
  end
end
