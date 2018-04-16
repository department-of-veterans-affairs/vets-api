# frozen_string_literal: true

require 'vet360/response'
require 'vet360/contact_information/async_response'

module Vet360
  module ContactInformation
    class EmailUpdateResponse < Vet360::ContactInformation::AsyncResponse
      attribute :email, Vet360::Models::Email

      attr_reader :email # @TODO these always arrive in a :bio object... should we call it that?

      def initialize(status, response = nil)
        @email = response&.body&.dig('bio')
        super(status, person: Vet360::Models::Person.from_response(@email))
      end

    end
  end
end
