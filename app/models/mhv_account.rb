# frozen_string_literal: true

require 'mhv_ac/client'

class MhvAccount < ActiveRecord::Base
  include AASM

  TERMS_AND_CONDITIONS_NAME = 'mhvac'
  INELIGIBLE_STATES = %i[
    needs_identity_verification needs_ssn_resolution needs_va_patient
    state_ineligible country_ineligible needs_terms_acceptance
  ].freeze
  # These will be refactored out
  LEGACY_STATES = %i[registered upgraded existing].freeze
  # These can probably refactored out too if we have timestamps those should suffice
  FAILED_STATES = %i[register_failed upgrade_failed].freeze
  # These states will replace the need for Legacy and Failed states
  ACCOUNT_STATES = %i[no_account basic advanced premium].freeze

  ALL_STATES = (INELIGIBLE_STATES + LEGACY_STATES + FAILED_STATES + ACCOUNT_STATES).freeze

  after_initialize :setup

  # rubocop:disable Metrics/BlockLength
  aasm(:account_state) do
    state :unknown, initial: true
    state *INELIGIBLE_STATES
    state *LEGACY_STATES
    state *FAILED_STATES
    state *ACCOUNT_STATES

    event :check_eligibility do
      transitions from: ALL_STATES, to: :needs_identity_verification, unless: :identity_proofed?
      transitions from: ALL_STATES, to: :needs_ssn_resolution, if: :ssn_mismatch?
      transitions from: ALL_STATES, to: :needs_va_patient, unless: :va_patient?
      transitions from: ALL_STATES, to: :has_multiple_active_mhv_ids, if: :multiple_active_mhv_ids?
      transitions from: ALL_STATES, to: :state_ineligible, unless: :state_eligible?
      transitions from: ALL_STATES, to: :country_ineligible, unless: :country_eligible?
      transitions from: ALL_STATES, to: :needs_terms_acceptance, unless: :terms_and_conditions_accepted?
      transitions from: ALL_STATES, to: :unknown
    end

    event :check_account_level do
      transitions from: %i[unknown], to: :no_account, unless: :exists?
      # The states below this line and the next comment will be removed when reintroducing upgrade.665
      transitions from: %i[unknown], to: :upgraded, if: :previously_upgraded?
      transitions from: %i[unknown], to: :existing, if: :registered_outside_vetsgov?
      transitions from: %i[unknown], to: :registered, if: :previously_registered?
      transitions from: %i[unknown], to: :unknown
      # These states will not happen if the above ones exist, but commenting them anyway
      # transitions from: %i[unknown], to: :basic, if: :basic_account?
      # transitions from: %i[unknown], to: :advanced, if: :advanced_account?
      # transitions from: %i[unknown], to: :premium, if: :premium_account?
      # transitions from: %i[unknown], to: :unknown
    end

    event :register do
      transitions from: %i[no_account register_failed], to: :registered
    end

    event :upgrade do
      transitions from: %i[registered upgrade_failed], to: :upgraded
    end

    event :fail_register do
      transitions from: [:no_account], to: :register_failed
    end

    event :fail_upgrade do
      transitions from: %i[registered], to: :upgrade_failed
    end
  end
  # rubocop:enable Metrics/BlockLength

  def creatable?
    may_register? || may_upgrade?
  end

  def terms_and_conditions_accepted?
    terms_and_conditions_accepted.present?
  end

  def exists?
    mhv_correlation_id.present?
  end

  private

  def user
    @user ||= User.find(user_uuid)
  end

  def mhv_correlation_id
    user.mhv_correlation_id
  end

  def identity_proofed?
    user.loa3?
  end

  def va_patient?
    user.va_patient?
  end

  def ssn_mismatch?
    user.ssn_mismatch?
  end

  def multiple_active_mhv_ids?
    false
  end

  def state_eligible?
    true
  end

  def country_eligible?
    true
  end

  def terms_and_conditions_accepted
    @terms_and_conditions_accepted ||=
      TermsAndConditionsAcceptance.joins(:terms_and_conditions)
                                  .includes(:terms_and_conditions)
                                  .where(terms_and_conditions: { latest: true, name: TERMS_AND_CONDITIONS_NAME })
                                  .where(user_uuid: user_uuid).limit(1).first
  end

  # deprecated after account upgrade reintroduced
  def registered_outside_vetsgov?
    exists? && !previously_registered?
  end

  # deprecated after account upgrade reintroduced
  def previously_upgraded?
    exists? && unknown? && upgraded_at?
  end

  # deprecated after account upgrade reintroduced
  def previously_registered?
    exists? && unknown? && registered_at?
  end

  def setup
    raise StandardError, 'You must use find_or_initialize_by(user_uuid: #)' if user_uuid.nil?
    check_eligibility if may_check_eligibility?
    check_account_level if may_check_account_level?
  end
end
