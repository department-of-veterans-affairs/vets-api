# frozen_string_literal: true

require 'evss/response'

module EVSS
  module DisabilityCompensationForm
    class FormSubmitResponse < EVSS::Response

      def initialize(status, response = nil)
        if response
          super(status, response.body)
        end
      end
    end
  end
end
