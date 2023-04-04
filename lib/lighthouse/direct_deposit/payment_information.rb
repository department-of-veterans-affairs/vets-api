# frozen_string_literal: true

require 'lighthouse/direct_deposit/control_information'
require 'lighthouse/direct_deposit/payment_account'

module Lighthouse
  module DirectDeposit
    class PaymentInformation < Base
      attr_accessor :status, :control_information, :payment_account

      def self.build_from(response)
        return if response.nil?

        Lighthouse::DirectDeposit::PaymentInformation.new(
          status: response.status,
          control_information: ControlInformation.build_from(response),
          payment_account: PaymentAccount.build_from(response)
        )
      end

      def body
        {
          control_information: @control_information,
          payment_account: @payment_account
        }
      end

      def ok?
        true
      end
    end
  end
end
