# frozen_string_literal: true

require_relative 'base'
require_relative 'control_information'
require_relative 'payment_account'

module Lighthouse
  module DirectDeposit
    class FinancialInstitution < Base
      attribute :payment_account, Lighthouse::DirectDeposit::PaymentAccount
      attribute :control_information, Lighthouse::DirectDeposit::ControlInformation

      # Converts a decoded JSON response from Lighthouse to an instance of the FinancialInstitution model
      # @param body [Hash] the decoded response body from Lighthouse
      # @return [Lighthouse::DirectDeposit::FinancialInstitution] the model built from the response body
      def self.build_from(body)
        payment_account = Lighthouse::DirectDeposit::PaymentAccount.build_from(body&.dig('paymentAccount'))
        control_information = Lighthouse::DirectDeposit::ControlInformation.build_from(body&.dig('controlInformation'))

        Lighthouse::DirectDeposit::FinancialInstitution.new(
          payment_account: payment_account,
          control_information: control_information
        )
      end
    end
  end
end

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
          name: body['financialInstitutionName'],
          account_type: body['accountType'],
          account_number: body['accountNumber'],
          routing_number: body['financialInstitutionRoutingNumber']
        )
      end
    end
  end
end

module Lighthouse
  module DirectDeposit
    class ControlInformation < Base
      attribute :can_update_direct_deposit, Boolean
      attribute :is_corp_available, Boolean
      attribute :is_corp_rec_found, Boolean
      attribute :has_no_bdn_payments, Boolean
      attribute :has_indentity, Boolean
      attribute :has_index, Boolean
      attribute :is_competent, Boolean
      attribute :has_mailing_address, Boolean
      attribute :has_no_fiduciary_assigned, Boolean
      attribute :is_not_deceased, Boolean
      attribute :has_payment_address, Boolean

      # Converts a decoded JSON response from Lighthouse to an instance of the ControlInformation model
      # @param body [Hash] the decoded response body from Lighthouse
      # @return [Lighthouse::DirectDeposit::ControlInformation] the model built from the response body
      def self.build_from(body)
        Lighthouse::DirectDeposit::ControlInformation.new(
          can_update_direct_deposit: body['canUpdateDirectDeposit'],
          is_corp_available: body['isCorpAvailable'],
          is_corp_rec_found: body['isCorpRecFound'],
          has_no_bdn_payments: body['hasNoBdnPayments'],
          has_indentity: body['hasIndentity'],
          has_index: body['hasIndex'],
          is_competent: body['isCompetent'],
          has_mailing_address: body['hasMailingAddress'],
          has_no_fiduciary_assigned: body['hasNoFiduciaryAssigned'],
          is_not_deceased: body['isNotDeceased'],
          has_payment_address: body['hasPaymentAddress']
        )
      end
    end
  end
end
