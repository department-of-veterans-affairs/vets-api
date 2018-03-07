# frozen_string_literal: true

require 'evss/response'

module EVSS
  module PCIU
    class PhoneNumberResponse < EVSS::Response
      attribute :phone, Hash

      def initialize(status, response = nil)
        phone = response&.body&.dig('cnp_phone')

        super(status, phone: phone)
      end
    end
  end
end
