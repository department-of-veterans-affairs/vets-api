# frozen_string_literal: true
require 'common/client/concerns/service_status'
require 'evss/response'

module EVSS
  module Letters
    class LettersResponse < EVSS::Response
      attribute :letters, Array[EVSS::Letters::Letter]
      attribute :address, EVSS::Letters::Address

      def parse_body(body)
        self.letters = body['letters']
        self.address = body['letter_destination']
      end

      def metadata
        super().merge(address: address)
      end
    end
  end
end
