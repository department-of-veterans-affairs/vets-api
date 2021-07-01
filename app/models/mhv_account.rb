# frozen_string_literal: true

require 'mhv_ac/client'

##
# Models an MHV Account
#
class MHVAccount < ApplicationRecord
  include AASM
  # http://grafana.vetsgov-internal/dashboard/db/mhv-account-creation
  # the following scopes are used for dashboard metrics in grafana and are collected
  # by the job in app/workers/mhv/account_statistics_job.rb
  scope :created, -> { where.not(registered_at: nil) }
  scope :existing_premium, -> { where(registered_at: nil, account_state: :upgraded, upgraded_at: nil) }
  scope :existing_upgraded, -> { where(registered_at: nil).where.not(upgraded_at: nil) }
  scope :existing_failed_upgrade, -> { where(registered_at: nil, upgraded_at: nil, account_state: :upgrade_failed) }
  scope :created_premium, -> { created.where(upgraded_at: nil, account_state: :upgraded) }
  scope :created_failed_upgrade, -> { created.where(account_state: :upgrade_failed) }
  scope :created_and_upgraded, -> { created.where.not(upgraded_at: nil) }
  scope :failed_create, -> { where(registered_at: nil, account_state: :register_failed) }
  # Prior to 08/2018 we did not track mhv_correlation_id, so we will be duplicating mhv account records, but because
  # accounts could have been deleted / reregistered etc, there is no way to reconcile the historic accounts without
  # reaching out to MHV for "historic" mhv_correlation_ids. Newly created records will be reflected as "active", but
  # "existing" even though they might have actually been created by us and a single uuid can track multiple
  # different mhv_correlation_ids even though only 1 should ever be the active one.
  scope :historic, -> { where(mhv_correlation_id: nil) }
  scope :active, -> { where.not(mhv_correlation_id: nil) }

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

  aasm(:account_state) do
    state :unknown, initial: true
    state(*(INELIGIBLE_STATES + ELIGIBLE_STATES + PERSISTED_STATES))

    after_all_transitions :track_state

    # This is eligibility for account creation or upgrade, not for access to services.
    event :check_eligibility do
      transitions from: ALL_STATES, to: :needs_identity_verification, unless: :identity_proofed?
      transitions from: ALL_STATES, to: :needs_ssn_resolution, if: :ssn_mismatch?
      transitions from: ALL_STATES, to: :needs_va_patient, unless: :va_patient?
      transitions from: ALL_STATES, to: :has_deactivated_mhv_ids, if: :deactivated_mhv_ids?
      transitions from: ALL_STATES, to: :has_multiple_active_mhv_ids, if: :multiple_active_mhv_ids?
      transitions from: ALL_STATES, to: :needs_terms_acceptance, if: :requires_terms_acceptance?
      transitions from: ALL_STATES, to: :eligible
    end

    # @todo revisit these in the future and see if they can be cleaned up
    # in the future might need to consider downgrades from upgrade, if account level can be changed.
    event :check_account_state do
      transitions from: %i[eligible], to: :no_account, unless: :exists?
      transitions from: %i[eligible], to: :upgraded, if: :previously_registered_somehow_upgraded?
      transitions from: %i[eligible], to: :registered, if: :previously_registered?
      transitions from: %i[eligible], to: :upgraded, if: :previously_upgraded?
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
  ##
  # @return [Boolean] is the MHV Account creatable?
  #
  def creatable?
    may_register?
  end

  ##
  # @return [Boolean] is the MHV Account upgradeable?
  #
  def upgradable?
    may_upgrade? && account_level.in?(UPGRADABLE_ACCOUNT_LEVELS)
  end

  ##
  # @return [Boolean] if the T&C have been accepted or not
  #
  def terms_and_conditions_accepted?
    terms_and_conditions_accepted.present?
  end

  ##
  # @return [TermsAndConditionsAcceptance] if the T&C have been accepted
  # @return [NilClass] if the T&C have not been accepted
  #
  def terms_and_conditions_accepted
    @terms_and_conditions_accepted ||=
      TermsAndConditionsAcceptance.joins(:terms_and_conditions)
                                  .includes(:terms_and_conditions)
                                  .where(terms_and_conditions: { latest: true, name: TERMS_AND_CONDITIONS_NAME })
                                  .where(user_uuid: user_uuid).limit(1).first
  end

  ##
  # @return [Boolean] is there an MHV Correlation ID?
  #
  def exists?
    mhv_correlation_id.present?
  end

  ##
  # @return [String] the user's MHV account type
  # @todo fix specs around these
  #
  def account_level
    user.mhv_account_type
  end

  ##
  # @return [Boolean] is the MHV Account already premium?
  #
  def already_premium?
    !previously_upgraded? && !created_at? && account_level == 'Premium'
  end

  ##
  # @param user [User] verifies UUID matches and then sets the user account
  #
  def user=(user)
    raise 'Invalid User UUID' unless user.uuid.to_s == user_uuid.to_s

    @user = user
    setup
    self.user
  end

  attr_reader :user

  private

  def track_state
    to_state = aasm(:account_state).to_state
    tracker_id = (user.uuid.to_s + mhv_correlation_id.to_s)
    if INELIGIBLE_STATES.include?(to_state)
      tracker = MHVAccountIneligible.find(tracker_id)
      return if tracker && tracker.account_state == to_state

      if tracker
        tracker.update(account_state: to_state)
      else
        attrs = { uuid: user.uuid, account_state: to_state,
                  mhv_correlation_id: mhv_correlation_id, icn: user.icn,
                  tracker_id: tracker_id }
        MHVAccountIneligible.create(attrs)
      end
      StatsD.increment("#{STATSD_ACCOUNT_INELIGIBLE_KEY}.#{to_state}")
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
      user.active_mhv_ids.size > 1
    end
  end

  def deactivated_mhv_ids?
    if previously_upgraded? || previously_registered?
      false
    else
      (user.mhv_ids.to_a - user.active_mhv_ids.to_a).any?
    end
  end

  def previously_upgraded?
    exists? && eligible? && upgraded_at? # could be existing or registered
  end

  def previously_registered?
    exists? && eligible? && registered_at? && !upgraded_at?
  end

  def previously_registered_somehow_upgraded?
    previously_registered? && changes[:account_state]&.first == 'upgraded'
  end

  def setup
    check_eligibility
    check_account_state if may_check_account_state?
  end
end
