# frozen_string_literal: true

require 'lighthouse/direct_deposit/payment_information'

module Lighthouse
  module DirectDeposit
    class PaymentInformationResponse
      attr_accessor :status, :body

      def initialize(status, body)
        payment_info = PaymentInformation.new(status, body)

        @status = payment_info.status
        @body = {
          control_information: payment_info.control_information,
          payment_account: payment_info.payment_account,
          error: payment_info.error
        }
      end
    end
  end
end
