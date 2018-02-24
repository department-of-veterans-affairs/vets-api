# frozen_string_literal: true

require 'evss/response'

module EVSS
  module PCIU
    class EmailAddressResponse < EVSS::Response
      attribute :email_address, Hash

      def initialize(status, response = nil)
        email_address = response&.body&.dig('cnp_email_address')

        super(status, email_address: email_address)
      end
    end
  end
end
