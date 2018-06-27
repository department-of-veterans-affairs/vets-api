# frozen_string_literal: true

require 'mhv_ac/client'

class MhvAccount < ActiveRecord::Base
  include AASM

  scope :accounts_created, -> { where.not(registered_at: nil) }
  scope :failed_create, -> { where(registered_at: nil, account_state: :register_failed) }
  scope :existing_accounts_upgraded, -> { where(registered_at: nil).where.not(upgraded_at: nil) }
  scope :created_failed_upgrade, -> { accounts_created.where(account_state: :upgrade_failed) }
  scope :created_and_upgraded, -> { accounts_created.where.not(upgraded_at: nil) }

  STATSD_ACCOUNT_INELIGIBLE_KEY = 'mhv.account.ineligible'
  TERMS_AND_CONDITIONS_NAME = 'mhvac'
  UPGRADABLE_ACCOUNT_LEVELS = [nil, 'Basic', 'Advanced'].freeze
  INELIGIBLE_STATES = %i[
    needs_identity_verification needs_ssn_resolution needs_va_patient
    has_deactivated_mhv_ids has_multiple_active_mhv_ids
    state_ineligible country_ineligible needs_terms_acceptance
  ].freeze
  PERSISTED_STATES = %i[registered upgraded register_failed upgrade_failed].freeze
  ELIGIBLE_STATES = %i[existing eligible no_account].freeze
  ALL_STATES = (%i[unknown] + INELIGIBLE_STATES + ELIGIBLE_STATES + PERSISTED_STATES).freeze

  after_initialize :setup

  # rubocop:disable Metrics/BlockLength
  aasm(:account_state) do
    state :unknown, initial: true
    state(*(INELIGIBLE_STATES + ELIGIBLE_STATES + PERSISTED_STATES))

    after_all_transitions :track_state

    # NOTE: This is eligibility for account creation or upgrade, not for access to services.
    event :check_eligibility do
      transitions from: ALL_STATES, to: :needs_identity_verification, unless: :identity_proofed?
      transitions from: ALL_STATES, to: :needs_ssn_resolution, if: :ssn_mismatch?
      transitions from: ALL_STATES, to: :needs_va_patient, unless: :va_patient?
      transitions from: ALL_STATES, to: :has_deactivated_mhv_ids, if: :deactivated_mhv_ids?
      transitions from: ALL_STATES, to: :has_multiple_active_mhv_ids, if: :multiple_active_mhv_ids?
      transitions from: ALL_STATES, to: :needs_terms_acceptance, if: :requires_terms_acceptance?
      transitions from: ALL_STATES, to: :eligible
    end

    event :check_account_state do
      transitions from: %i[eligible], to: :no_account, unless: :exists?
      # The states below this line and the next comment will be removed when reintroducing upgrade.665
      transitions from: %i[eligible], to: :upgraded, if: :previously_upgraded?
      transitions from: %i[eligible], to: :registered, if: :previously_registered?
      # this could mean that vets.gov created / upgraded before we started tracking mhv_ids
      transitions from: %i[eligible], to: :existing
    end

    event :register do
      transitions from: %i[register_failed no_account], to: :registered
    end

    # we will upgrade existing account only if it has not been previously upgraded (even if subsequently downgraded)
    event :upgrade do
      transitions from: %i[upgrade_failed existing registered], to: :upgraded, unless: :already_premium?
    end

    event :existing_premium do
      transitions from: %i[existing], to: :existing, if: :already_premium?
    end

    event :fail_register do
      transitions from: [:no_account], to: :register_failed
    end

    event :fail_upgrade do
      transitions from: %i[registered existing], to: :upgrade_failed
    end
  end
  # rubocop:enable Metrics/BlockLength

  def creatable?
    may_register?
  end

  def upgradable?
    may_upgrade? && account_level.in?(UPGRADABLE_ACCOUNT_LEVELS)
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

  # if vets.gov upgraded the account it is premium, if not, we have to check eligible data classes
  # NOTE: individual services should always check mhv_account_type using eligible data classes since
  # it is possible for accounts to get downgraded.
  def account_level
    return 'Advanced' if registered?
    return 'Advanced' if upgrade_failed? && registered_at.present?
    return 'Premium' if upgraded?
    user.mhv_account_type
  end

  def user
    @user ||= User.find(user_uuid)
  end

  def already_premium?
    account_level == 'Premium' && !previously_upgraded?
  end

  private

  def track_state
    if INELIGIBLE_STATES.include?(aasm(:account_state).to_state)
      tracker = MHVAccountIneligible.find(user.uuid)
      return if tracker && tracker.account_state == aasm(:account_state).to_state
      if tracker
        tracker.update(account_state: aasm(:account_state).to_state)
      else
        attrs = { uuid: user.uuid, account_state: aasm(:account_state).to_state,
                  mhv_correlation_id: mhv_correlation_id, icn: user.icn }
        MHVAccountIneligible.create(attrs)
      end
      StatsD.increment("#{STATSD_ACCOUNT_INELIGIBLE_KEY}.#{aasm(:account_state).to_state}")
    end
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

  def requires_terms_acceptance?
    return false if account_level == 'Premium'
    !terms_and_conditions_accepted?
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

  def previously_upgraded?
    exists? && eligible? && upgraded_at?
  end

  def previously_registered?
    exists? && eligible? && registered_at?
  end

  def setup
    check_eligibility
    check_account_state if may_check_account_state?
  end
end
