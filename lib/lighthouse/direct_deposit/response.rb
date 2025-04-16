# frozen_string_literal: true

module Lighthouse
  module DirectDeposit
    class Response
      attr_accessor :status, :control_information, :payment_account, :veteran_status

      def initialize(status, control_information, payment_account, veteran_status)
        @status = status
        @control_information = control_information
        @payment_account = payment_account
        @veteran_status = veteran_status
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
          payment_account: @payment_account,
          veteran_status: @veteran_status
        }
      end

      def error?
        false
      end
    end
  end
end
