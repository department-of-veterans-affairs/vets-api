# frozen_string_literal: true

require 'mhv_ac/client'

class MhvAccount < ActiveRecord::Base
  include AASM

  TERMS_AND_CONDITIONS_NAME = 'mhvac'
  # Everything except existing and ineligible accounts should be able to transition to :needs_terms_acceptance
  ALL_STATES = %i[
    unknown
    needs_terms_acceptance
    existing
    ineligible
    registered
    upgraded
    register_failed
    upgrade_failed
  ].freeze

  after_initialize :setup

  aasm(:account_state) do
    state :unknown, initial: true
    state :needs_terms_acceptance, :existing, :ineligible, :registered, :upgraded, :register_failed, :upgrade_failed

    event :check_eligibility do
      transitions from: ALL_STATES, to: :existing, if: :preexisting_account?
      transitions from: ALL_STATES, to: :ineligible, unless: :eligible?
      transitions from: ALL_STATES, to: :upgraded, if: :previously_upgraded?
      transitions from: ALL_STATES, to: :registered, if: :previously_registered?
      transitions from: ALL_STATES, to: :unknown
    end

    event :check_terms_acceptance do
      transitions from: ALL_STATES - %i[existing ineligible],
                  to: :needs_terms_acceptance, unless: :terms_and_conditions_accepted?
    end

    event :register do
      transitions from: %i[unknown register_failed], to: :registered
    end

    event :upgrade do
      transitions from: %i[unknown registered upgrade_failed], to: :upgraded
    end

    event :fail_register do
      transitions from: [:unknown], to: :register_failed
    end

    event :fail_upgrade do
      transitions from: %i[unknown registered], to: :upgrade_failed
    end
  end

  def create_and_upgrade!
    unless existing?
      create_mhv_account! unless previously_registered?
      upgrade_mhv_account!
    end
  end

  def eligible?
    user.loa3? && user.va_patient?
  end

  def terms_and_conditions_accepted?
    terms_and_conditions_accepted.present?
  end

  def preexisting_account?
    mhv_correlation_id.present? && !previously_registered?
  end

  def accessible?
    return false if mhv_correlation_id.blank?
    (user.loa3? || user.authn_context.include?('myhealthevet')) && (upgraded? || existing?)
  end

  def terms_and_conditions_accepted
    @terms_and_conditions_accepted ||=
      TermsAndConditionsAcceptance.joins(:terms_and_conditions)
                                  .includes(:terms_and_conditions)
                                  .where(terms_and_conditions: { latest: true, name: TERMS_AND_CONDITIONS_NAME })
                                  .where(user_uuid: user_uuid).limit(1).first
  end

  def previously_upgraded?
    eligible? && upgraded_at?
  end

  def previously_registered?
    eligible? && registered_at?
  end

  private

  def user
    @user ||= User.find(user_uuid)
  end

  def mhv_correlation_id
    user.mhv_correlation_id
  end

  def create_mhv_account!
    mhv_accounts_service.create
  end

  def upgrade_mhv_account!
    mhv_accounts_service.upgrade
  end

  def mhv_accounts_service
    @mhv_accounts_service || MhvAccountsService.new(user)
  end

  def setup
    raise StandardError, 'You must use find_or_initialize_by(user_uuid: #)' if user_uuid.nil?
    check_eligibility unless accessible?
    check_terms_acceptance if may_check_terms_acceptance?
  end
end
