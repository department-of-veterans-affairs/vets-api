# frozen_string_literal: true

require 'vet360/response'

module Vet360
  module ContactInformation
    class PersonResponse < Vet360::Response
      attribute :person, Hash

      def initialize(status, response = nil)
        # TODO - how do we want to customize the response
        bio = response&.body&.dig('bio')
byebug
        super(status, person: bio)
      end

      private

      def build_person(response)
        Person.new(
          emails: build_emails,
          telephones: build_telephones
        )
      end

      def build_emails
        # array of email_address hashes
      end

      def build_telephones
        # array of telephone hashes
      end
    end
  end
end
