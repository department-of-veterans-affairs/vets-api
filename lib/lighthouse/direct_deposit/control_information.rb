# frozen_string_literal: true

module Lighthouse
  module DirectDeposit
    class ControlInformation
      include ActiveModel::Model

      ACTIONS = [:can_update_direct_deposit].freeze
      USAGES = %i[is_corp_available is_edu_claim_available].freeze
      RESTRICTIONS = %i[
        is_corp_rec_found
        has_no_bdn_payments
        has_identity
        has_index
        is_competent
        has_mailing_address
        has_no_fiduciary_assigned
        is_not_deceased
        has_payment_address
      ].freeze

      attr_accessor(*(ACTIONS + USAGES + RESTRICTIONS))
      attr_reader :errors

      alias :comp_and_pen? is_corp_available
      alias :edu_benefits? is_edu_claim_available

      def account_updatable?
        @can_update_direct_deposit && restrictions.size.zero?
      end

      def benefit_type?
        comp_and_pen? || edu_benefits?
      end

      def restrictions
        RESTRICTIONS.reject { |name| send(name) }
      end

      def clear_restrictions
        @can_update_direct_deposit = true
        RESTRICTIONS.each { |name| send("#{name}=", true) }
      end

      def valid?
        @errors = []

        error = 'Has restrictions. Account should not be updatable.'
        errors << error if @can_update_direct_deposit && restrictions.any?

        error = 'Has no restrictions. Account should be updatable.'
        errors << error if !@can_update_direct_deposit && restrictions.empty?

        error = 'Missing benefit type. Must be either CnP or EDU benefits.'
        errors << error unless benefit_type?

        errors.size.zero?
      end
    end
  end
end
