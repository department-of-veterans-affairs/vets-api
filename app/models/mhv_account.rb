class MhvAccount < ActiveRecord::Base
  include AASM

  has_many :terms_and_conditions_acceptances, foreign_key: :user_uuid, primary_key: :user_uuid
  has_many :premium_account_terms, -> { where(terms_and_conditions: { latest: true, name: 'mhv_account_terms' }) },
                                   through: :terms_and_conditions_acceptances,
                                   source: :terms_and_conditions,
                                   foreign_key: :user_uuid,
                                   primary_key: :user_uuid

  # Everything except ineligible accounts should be able to transition to :needs_terms_acceptance
  STATES_REQUIRING_TERMS_ACCEPTANCE = %i(unknown existing_account registered upgraded register_failed upgrade_failed).freeze
  before_initialize :initialize_state

  aasm(:account_state) do
    state :needs_terms_acceptance, initial: true
    state :unknown, :ineligible, :registered, :upgraded, :register_failed, :upgrade_failed

    event :initialize_state do
      transitions from: [:unknown, :existing_account], to: :ineligible, unless: :mhv_account_eligible?
      transitions from: :unknown, to: :existing_account, if: :prexisting_account?
      transitions from: STATES_REQUIRING_TERMS_ACCEPTANCE, to: :needs_terms_acceptance, unless: :terms_and_conditions_accepted?
    end

    event :register do
      transitions from: [:unknown, :register_failed], to: :registered
    end

    event :upgrade do
      transitions from: [:registered, :existing_account, :upgrade_failed], to: :upgraded
    end
  end

  def create_and_upgrade!
    create_mhv_account!
    upgrade_mhv_account!
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

  def terms_and_conditions_accepted?
    premium_account_terms.any?
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

  def prexisting_account?
     user.mhv_correlation_id.present?
  end

  def veteran?
    # TODO: this field is derived from eMIS and might have pending ATO considerations for us to use it.
    true
  end
end
