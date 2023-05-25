# frozen_string_literal: true

require 'lighthouse/direct_deposit/response'

module Lighthouse
  module DirectDeposit
    class PaymentInfoParser
      def self.parse(response)
        return if response.nil? || response.body.nil?

        status = response.status
        control_info = parse_control_info(response.body['control_information'])
        payment_account = parse_payment_account(response.body['payment_account'])

        Lighthouse::DirectDeposit::Response.new(status, control_info, payment_account)
      end

      def self.parse_control_info(control_information)
        return if control_information.nil?

        control_information['has_identity'] = control_information.delete('has_indentity')
        control_information
      end

      def self.parse_payment_account(payment_account)
        return if payment_account.nil?

        {
          name: payment_account['financial_institution_name'],
          account_type: payment_account['account_type'],
          account_number: payment_account['account_number'],
          routing_number: payment_account['financial_institution_routing_number']
        }
      end
    end
  end
end
