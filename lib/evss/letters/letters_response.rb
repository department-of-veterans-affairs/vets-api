# frozen_string_literal: true
require 'common/client/concerns/service_status'
require 'evss/response'

module EVSS
  module Letters
    class LettersResponse < EVSS::Response
      include Common::Client::ServiceStatus

      attribute :letters, Array[EVSS::Letters::Letter]
      attribute :address, EVSS::Letters::Address

      def initialize(status, response = nil)
        super(status)
        if response
          self.letters = response.body['letters']
          self.address = response.body['letter_destination']
        end
      end

      def metadata
        super().merge(address: address)
      end
    end
  end
end
