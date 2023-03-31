# frozen_string_literal: true

require_relative 'base'

module Lighthouse
  module DirectDeposit
    class PaymentAccount < Base
      attribute :name, String
      attribute :account_type, String
      attribute :account_number, String
      attribute :routing_number, String

      ACCOUNT_NUM_REGEX = /\A\d*\z/
      ROUTING_NUM_REGEX = /\A\d{9}\z/

      validates :account_type, inclusion: { in: %w[CHECKING SAVINGS] }, presence: true
      validates :account_number, presence: true
      validates :routing_number, presence: true

      validates_format_of :account_number, with: ACCOUNT_NUM_REGEX
      validates_format_of :routing_number, with: ROUTING_NUM_REGEX

      # Converts a decoded JSON response from Lighthouse to an instance of the PaymentAccount model
      # @param body [Hash] the decoded response body from Lighthouse
      # @return [Lighthouse::DirectDeposit::PaymentAccount] the model built from the response body
      def self.build_from(response)
        payment_account = response&.body&.dig('paymentAccount')

        return if payment_account.nil?

        Lighthouse::DirectDeposit::PaymentAccount.new(
          name: payment_account['financialInstitutionName'],
          account_type: payment_account['accountType'],
          account_number: payment_account['accountNumber'],
          routing_number: payment_account['financialInstitutionRoutingNumber']
        )
      end

      def account_type
        @account_type&.upcase
      end
    end
  end
end
