# frozen_string_literal: true

require_relative 'base'

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
          can_update_direct_deposit: body['can_update_direct_deposit'],
          is_corp_available: body['is_corp_available'],
          is_corp_rec_found: body['is_corp_rec_found'],
          has_no_bdn_payments: body['has_no_bdn_payments'],
          has_indentity: body['has_indentity'],
          has_index: body['has_index'],
          is_competent: body['is_competent'],
          has_mailing_address: body['has_mailing_address'],
          has_no_fiduciary_assigned: body['has_no_fiduciary_assigned'],
          is_not_deceased: body['is_not_deceased'],
          has_payment_address: body['has_payment_address']
        )
      end
    end
  end
end
