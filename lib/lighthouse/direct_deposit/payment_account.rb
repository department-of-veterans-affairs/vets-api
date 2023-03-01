# frozen_string_literal: true

require_relative 'base'

module Lighthouse
  module DirectDeposit
    class PaymentAccount < Base
      attribute :name, String
      attribute :account_type, String
      attribute :account_number, String
      attribute :routing_number, String

      # Converts a decoded JSON response from Lighthouse to an instance of the PaymentAccount model
      # @param body [Hash] the decoded response body from Lighthouse
      # @return [Lighthouse::DirectDeposit::PaymentAccount] the model built from the response body
      def self.build_from(body)
        Lighthouse::DirectDeposit::PaymentAccount.new(
          name: body['financial_institution_name'],
          account_type: body['account_type'],
          account_number: body['account_number'],
          routing_number: body['financial_institution_routing_number']
        )
      end
    end
  end
end
