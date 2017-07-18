# frozen_string_literal: true
require 'common/client/concerns/service_status'
require 'evss/response'

module EVSS
  module Letters
    class LettersResponse < EVSS::Response
      attribute :letters, Array[EVSS::Letters::Letter]
      attribute :address, EVSS::Letters::Address

      def initialize(status, response = nil)
        if response
          attributes = {
            letters: response.body['letters'],
            address: response.body['letter_destination']
          }
        end
        super(status, attributes)
      end

      def metadata
        meta = super
        meta[:address] = address if ok?
        meta
      end
    end
  end
end
