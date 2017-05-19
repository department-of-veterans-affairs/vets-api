class MhvAccount < ActiveRecord::Base
  include AASM

  # Everything except ineligible accounts should be able to transition to :needs_terms_acceptance
  ALL_STATES = %i(unknown needs_terms_acceptance ineligible registered upgraded register_failed upgrade_failed)
  after_initialize :setup

  aasm(:account_state) do
    state :unknown, initial: true
    state :needs_terms_acceptance, :ineligible, :registered, :upgraded, :register_failed, :upgrade_failed

    event :check_eligibility do
      transitions from: ALL_STATES, to: :ineligible, unless: :mhv_account_eligible?
      transitions from: ALL_STATES, to: :upgraded, if: :previously_upgraded?
      transitions from: ALL_STATES, to: :registered, if: :previously_registered?
      transitions from: ALL_STATES, to: :unknown
    end

    event :check_terms_acceptance do
      transitions from: ALL_STATES, to: :needs_terms_acceptance, unless: :terms_and_conditions_accepted?
    end

    event :registered do
      transitions from: [:unknown, :register_failed], to: :registered
    end

    event :upgraded do
      transitions from: [:unknown, :registered, :upgrade_failed], to: :upgraded
    end
  end

  def create_and_upgrade!
    create_mhv_account! unless preexisting_account?
    upgrade_mhv_account!
  end

  def terms_and_conditions_accepted?
    TermsAndConditionsAcceptance.joins(:terms_and_conditions)
                                .where(terms_and_conditions: { latest: true, name: 'mhv_account_terms' })
                                .where(user_uuid: user.uuid).exists?
  end

  private

  def user
    @user ||= User.find(user_uuid)
  end

  def va_patient?
    # TODO: This needs to be changed to check if ICN is within a certain range.
    user&.icn.present?
  end

  def mhv_account_eligible?
    va_patient?
  end

  def preexisting_account?
     user&.mhv_correlation_id.present?
  end

  def veteran?
    # TODO: this field is derived from eMIS and might have pending ATO considerations for us to use it.
    true
  end

  def create_mhv_account!
    if may_register?
      # TODO: invoke client to register the account
      # if success
      # registered_at = Time.current
      # register!
      # else
      # account_state = 'register_failed'
      # save
    else
      # raise some error with current status
    end
  end

  def upgrade_mhv_account!
    if may_upgrade?
      # TODO: invoke client to upgrade the account
      # if success
      # upgraded_at = Time.current
      # upgrade!
      # else
      # account_state = 'upgrade_failed'
      # save
    else
      # raise some error with current status
    end
  end

  def previously_upgraded?
    mhv_account_eligible? && upgraded_at?
  end

  def previously_registered?
    mhv_account_eligible? && registered_at?
  end

  def setup
    raise StandardError, 'You must use find_or_initialize_by(user_uuid: #)' if user_uuid.nil?
    check_eligibility
    check_terms_acceptance if may_check_terms_acceptance? && !ineligible?
  end
end
