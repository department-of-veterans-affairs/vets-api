# frozen_string_literal: true

module Lighthouse
  module DirectDeposit
    class ControlInformation
      include ActiveModel::Attributes
      include ActiveModel::AttributeAssignment

      # Actions
      attribute :can_update_direct_deposit, :boolean

      # Usage
      attribute :is_corp_available, :boolean
      attribute :is_edu_claim_available, :boolean

      # Restrictions
      attribute :is_corp_rec_found, :boolean
      attribute :has_no_bdn_payments, :boolean
      attribute :has_identity, :boolean
      attribute :has_index, :boolean
      attribute :is_competent, :boolean
      attribute :has_mailing_address, :boolean
      attribute :has_no_fiduciary_assigned, :boolean
      attribute :is_not_deceased, :boolean
      attribute :has_payment_address, :boolean

      attr_reader :errors

      alias :comp_and_pen? is_corp_available
      alias :edu_benefits? is_edu_claim_available

      def account_updatable?
        can_update_direct_deposit.present? && restrictions.size.zero?
      end

      def benefit_type?
        comp_and_pen? || edu_benefits?
      end

      def benefit_type
        return 'both' if comp_and_pen? && edu_benefits?
        return 'cnp' if comp_and_pen?
        return 'edu' if edu_benefits?

        'none'
      end

      def restrictions
        restrictions = []
        restrictions << 'is_corp_rec_found' unless is_corp_rec_found
        restrictions << 'has_no_bdn_payments' unless has_no_bdn_payments
        restrictions << 'has_identity' unless has_identity
        restrictions << 'has_index' unless has_index
        restrictions << 'is_competent' unless is_competent
        restrictions << 'has_mailing_address' unless has_mailing_address
        restrictions << 'has_no_fiduciary_assigned' unless has_no_fiduciary_assigned
        restrictions << 'is_not_deceased' unless is_not_deceased
        restrictions << 'has_payment_address' unless has_payment_address
        restrictions
      end

      def clear_restrictions
        assign_attributes can_update_direct_deposit: true
        assign_attributes is_corp_rec_found: true
        assign_attributes has_no_bdn_payments: true
        assign_attributes has_identity: true
        assign_attributes has_index: true
        assign_attributes is_competent: true
        assign_attributes has_mailing_address: true
        assign_attributes has_no_fiduciary_assigned: true
        assign_attributes is_not_deceased: true
        assign_attributes has_payment_address: true
      end

      def valid?
        @errors = []

        error = 'Has restrictions. Account should not be updatable.'
        @errors << error if can_update_direct_deposit && restrictions.any?

        error = 'Has no restrictions. Account should be updatable.'
        @errors << error if !can_update_direct_deposit && restrictions.empty?

        error = 'Missing benefit type. Must be either CnP or EDU benefits.'
        @errors << error unless benefit_type?

        @errors.size.zero?
      end
    end
  end
end
