# frozen_string_literal: true

require 'evss/response'

module EVSS
  module PCIU
    class PhoneNumberResponse < EVSS::Response
      attribute :country_code, String
      attribute :number, String
      attribute :extension, String

      def initialize(status, response = nil)
        attributes = {
          country_code: response&.body&.dig('cnp_phone', 'country_code'),
          number: response&.body&.dig('cnp_phone', 'number'),
          extension: response&.body&.dig('cnp_phone', 'extension')
        }

        super(status, attributes)
      end
    end
  end
end
