# frozen_string_literal: true

module EVSS
  module PPIU
    class PaymentInformationResponse < EVSS::Response
      attribute :responses, Array[EVSS::PPIU::PaymentInformation]

      def initialize(status, response = nil)
        super(status, response.body) if response
      end
    end
  end
end
