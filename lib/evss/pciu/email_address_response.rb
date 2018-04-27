# frozen_string_literal: true

require 'evss/response'

module EVSS
  module PCIU
    class EmailAddressResponse < EVSS::Response
      attribute :email, String
      attribute :effective_at, String

      def initialize(status, response = nil)
        attributes = {
          email: response&.body&.dig('cnp_email_address', 'value'),
          effective_at: response&.body&.dig('cnp_email_address', 'effective_date')
        }

        super(status, attributes)
      end
    end
  end
end
