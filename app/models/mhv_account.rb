# frozen_string_literal: true

require 'mhv_ac/client'

class MhvAccount < ActiveRecord::Base
  include AASM

  TERMS_AND_CONDITIONS_NAME = 'mhvac'
  INELIGIBLE_STATES = %i[
    needs_identity_verification needs_ssn_resolution needs_va_patient
    has_deactivated_mhv_ids has_multiple_active_mhv_ids
    state_ineligible country_ineligible needs_terms_acceptance
  ].freeze

  PERSISTED_STATES = %i[register_failed upgrade_failed registered upgraded existing].freeze
  ELIGIBLE_STATES = %i[no_account].freeze
  ALL_STATES = (%i[unknown] + INELIGIBLE_STATES + ELIGIBLE_STATES + PERSISTED_STATES).freeze

  after_initialize :setup

  # rubocop:disable Metrics/BlockLength
  aasm(:account_state) do
    state :unknown, initial: true
    state(*ALL_STATES)

    # NOTE: This is eligibility for account creation or upgrade, not for access to services.
    event :check_eligibility do
      transitions from: ALL_STATES, to: :needs_identity_verification, unless: :identity_proofed?
      transitions from: ALL_STATES, to: :needs_ssn_resolution, if: :ssn_mismatch?
      transitions from: ALL_STATES, to: :needs_va_patient, unless: :va_patient?
      transitions from: ALL_STATES, to: :has_deactivated_mhv_ids, if: :deactivated_mhv_ids?
      transitions from: ALL_STATES, to: :has_multiple_active_mhv_ids, if: :multiple_active_mhv_ids?
      transitions from: ALL_STATES, to: :state_ineligible, unless: :state_eligible?
      transitions from: ALL_STATES, to: :country_ineligible, unless: :country_eligible?
      transitions from: ALL_STATES, to: :needs_terms_acceptance, unless: :terms_and_conditions_accepted?
      transitions from: ALL_STATES, to: :unknown
    end

    event :check_account_state do
      transitions from: %i[unknown], to: :no_account, unless: :exists?
      # The states below this line and the next comment will be removed when reintroducing upgrade.665
      transitions from: %i[unknown], to: :upgraded, if: :previously_upgraded?
      transitions from: %i[unknown], to: :registered, if: :previously_registered?
      # this could mean that vets.gov created / upgraded before we started tracking mhv_ids
      transitions from: %i[unknown], to: :existing
    end

    event :register do
      transitions from: %i[no_account], to: :registered
    end

    event :upgrade do
      transitions from: %i[registered existing], to: :upgraded
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
    may_register?
  end

  def upgradable?
    may_upgrade? && [nil, 'Basic', 'Advanced'].include?(account_level)
  end

  def terms_and_conditions_accepted?
    terms_and_conditions_accepted.present?
  end

  def terms_and_conditions_accepted
    @terms_and_conditions_accepted ||=
      TermsAndConditionsAcceptance.joins(:terms_and_conditions)
                                  .includes(:terms_and_conditions)
                                  .where(terms_and_conditions: { latest: true, name: TERMS_AND_CONDITIONS_NAME })
                                  .where(user_uuid: user_uuid).limit(1).first
  end

  def exists?
    mhv_correlation_id.present?
  end

  def account_level
    user.mhv_account_type
  end

  private

  def user
    @user ||= User.find(user_uuid)
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
    if previously_upgraded? || previously_registered?
      false
    else
      user.va_profile.active_mhv_ids.size > 1
    end
  end

  def deactivated_mhv_ids?
    if previously_upgraded? || previously_registered?
      false
    else
      (user.va_profile.mhv_ids - user.va_profile.active_mhv_ids).to_a.any?
    end
  end

  # for now lets not handle this
  def state_eligible?
    true
  end

  # fot now lets not handle this
  def country_eligible?
    true
  end

  def previously_upgraded?
    exists? && unknown? && upgraded_at?
  end

  def previously_registered?
    exists? && unknown? && registered_at?
  end

  def setup
    check_eligibility
    check_account_state if may_check_account_state?
  end
end
