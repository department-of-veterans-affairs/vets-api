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

      def initialize(status, response = nil)
        self.status = status
        if response
          self.letters = response.body['letters']
          self.address = response.body['letter_destination']
        end
      end

      def ok?
        status == 200
      end

      def metadata
        {
          address: address,
          status: response_status
        }
      end

      def response_status
        case status
        when 200
          RESPONSE_STATUS[:ok]
        when 403
          RESPONSE_STATUS[:not_authorized]
        when 404
          RESPONSE_STATUS[:not_found]
        else
          RESPONSE_STATUS[:server_error]
        end
      end
    end
  end
end
