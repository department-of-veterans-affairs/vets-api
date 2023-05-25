# frozen_string_literal: true

module Lighthouse
  module DirectDeposit
    class Response
      attr_accessor :status, :control_information, :payment_account

      def initialize(status, control_information, payment_account)
        @status = status
        @control_information = control_information
        @payment_account = payment_account
      end

      def response
        {
          status: @status,
          body:
        }
      end

      def body
        {
          control_information: @control_information,
          payment_account: @payment_account
        }
      end

      def error?
        false
      end
    end
  end
end
