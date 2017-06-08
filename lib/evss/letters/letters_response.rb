# frozen_string_literal: true
require 'common/client/concerns/service_status'
require 'common/models/base'

module EVSS
  module Letters
    class LettersResponse < Common::Base
      include Common::Client::ServiceStatus

      attribute :status, Integer
      attribute :letters, Array[EVSS::Letters::Letter]
      attribute :address, EVSS::Letters::Address

      def initialize(raw_response)
        self.letters = raw_response.body['letters']
        self.address = raw_response.body['letter_destination']
        self.status = raw_response.status
      end

      def ok?
        status == 200
      end

      def metadata
        {
          address: address,
          status: ok? ? RESPONSE_STATUS[:ok] : RESPONSE_STATUS[:server_error]
        }
      end
    end
  end
end
