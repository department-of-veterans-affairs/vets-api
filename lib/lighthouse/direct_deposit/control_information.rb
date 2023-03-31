# frozen_string_literal: true

require_relative 'base'

module Lighthouse
  module DirectDeposit
    class ControlInformation < Base
      attribute :can_update_direct_deposit, Boolean
      attribute :is_corp_available, Boolean
      attribute :is_corp_rec_found, Boolean
      attribute :has_no_bdn_payments, Boolean
      attribute :has_identity, Boolean
      attribute :has_index, Boolean
      attribute :is_competent, Boolean
      attribute :has_mailing_address, Boolean
      attribute :has_no_fiduciary_assigned, Boolean
      attribute :is_not_deceased, Boolean
      attribute :has_payment_address, Boolean

      # Converts a decoded JSON response from Lighthouse to an instance of the ControlInformation model
      # @param response [Hash] from Lighthouse
      # @return [Lighthouse::DirectDeposit::ControlInformation] the model built from the response body
      def self.build_from(response)
        control_info = response&.body&.dig('controlInformation')

        return if control_info.nil?

        Lighthouse::DirectDeposit::ControlInformation.new(
          can_update_direct_deposit: control_info['canUpdateDirectDeposit'],
          is_corp_available: control_info['isCorpAvailable'],
          is_corp_rec_found: control_info['isCorpRecFound'],
          has_no_bdn_payments: control_info['hasNoBdnPayments'],
          has_identity: control_info['hasIndentity'], # correct spelling error from Lighthouse
          has_index: control_info['hasIndex'],
          is_competent: control_info['isCompetent'],
          has_mailing_address: control_info['hasMailingAddress'],
          has_no_fiduciary_assigned: control_info['hasNoFiduciaryAssigned'],
          is_not_deceased: control_info['isNotDeceased'],
          has_payment_address: control_info['hasPaymentAddress']
        )
      end

      def authorized?
        can_update_direct_deposit
      end
    end
  end
end
