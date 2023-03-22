# frozen_string_literal: true

require 'lighthouse/direct_deposit/control_information'
require 'lighthouse/direct_deposit/payment_account'
require 'lighthouse/direct_deposit/error'

module Lighthouse
  module DirectDeposit
    class PaymentInformation
      attr_reader :status, :control_information, :payment_account

      def initialize(status, body)
        @status = status
        @control_information = build_control_information(status, body)

        if @control_information.nil?
          @error = build_error(status, body)
        elsif authorized?
          @payment_account = build_payment_account(status, body)
          @error = build_error(status, body)
        else
          @status = 403
          @error = error
        end
      end

      def build_control_information(status, body)
        ControlInformation.build_from(status, body) if status.between?(200, 299)
      end

      def build_payment_account(status, body)
        PaymentAccount.build_from(status, body)
      end

      def build_error(status, body)
        Error.build_from(status, body) if status.between?(400, 599)
      end

      def authorized?
        status.between?(200, 299) && @control_information&.authorized?
      end

      def error
        return @error if @error.present?
        return @control_information&.error_message unless authorized?
      end
    end
  end
end
