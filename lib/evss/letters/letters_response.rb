# frozen_string_literal: true
require 'common/client/concerns/service_status'
require 'evss/response'

module EVSS
  module Letters
    class LettersResponse < EVSS::Response
      attribute :letters, Array[EVSS::Letters::Letter]

      def initialize(status, response = nil)
        if response
          attributes = {
            letters: response.body['letters']
          }
        end
        super(status, attributes)
      end
    end
  end
end
