# frozen_string_literal: true
require 'mhv_ac/client'
require 'sentry_logging'
require 'beta_switch'

class MhvAccount < ActiveRecord::Base
  include AASM
  include SentryLogging
  include BetaSwitch

  TERMS_AND_CONDITIONS_NAME = 'mhvac'
  # Everything except ineligible accounts should be able to transition to :needs_terms_acceptance
  ALL_STATES = %i(unknown needs_terms_acceptance ineligible registered upgraded register_failed upgrade_failed).freeze
  # Range of VHA facility IDs at which people receive treatment
  PATIENT_FACILITY_RANGE = [358, 758].freeze
  after_initialize :setup

  aasm(:account_state) do
    state :unknown, initial: true
    state :needs_terms_acceptance, :ineligible, :registered, :upgraded, :register_failed, :upgrade_failed

    event :check_eligibility do
      transitions from: ALL_STATES, to: :ineligible, unless: :eligible?
      transitions from: ALL_STATES, to: :upgraded, if: :previously_upgraded?
      transitions from: ALL_STATES, to: :registered, if: :previously_registered?
      transitions from: ALL_STATES, to: :unknown
    end

    event :check_terms_acceptance do
      transitions from: ALL_STATES - [:ineligible], to: :needs_terms_acceptance, unless: :terms_and_conditions_accepted?
    end

    event :register do
      transitions from: [:unknown, :register_failed], to: :registered
    end

    event :upgrade do
      transitions from: [:unknown, :registered, :upgrade_failed], to: :upgraded
    end

    event :fail_register do
      transitions from: [:unknown], to: :register_failed
    end

    event :fail_upgrade do
      transitions from: [:unknown, :registered], to: :upgrade_failed
    end
  end

  def create_and_upgrade!
    create_mhv_account! unless preexisting_account?
    upgrade_mhv_account!
  end

  def eligible?
    va_patient?
  end

  def terms_and_conditions_accepted?
    terms_and_conditions_accepted.present?
  end

  def preexisting_account?
    user&.mhv_correlation_id.present?
  end

  private

  def terms_and_conditions_accepted
    @terms_and_conditions_accepted ||=
      TermsAndConditionsAcceptance.joins(:terms_and_conditions)
                                  .includes(:terms_and_conditions)
                                  .where(terms_and_conditions: { latest: true, name: TERMS_AND_CONDITIONS_NAME })
                                  .where(user_uuid: user.uuid).limit(1).first
  end

  def params_for_registration
    {
      icn: user.icn,
      is_patient: va_patient?,
      is_veteran: veteran?,
      address1: user.va_profile.address.street,
      city: user.va_profile.address.city,
      state: user.va_profile.address.state,
      zip: user.va_profile.address.postal_code,
      country: user.va_profile.address.country,
      province: nil, # TODO: We need to determine if this is something that could actually happen (non USA)
      email: user.email,
      home_phone: user.va_profile.home_phone,
      sign_in_partners: 'VETS.GOV',
      terms_version: terms_and_conditions_accepted.terms_and_conditions.version,
      terms_accepted_date: terms_and_conditions_accepted.created_at
    }
  end

  def params_for_upgrade
    {
      user_id: user.mhv_correlation_id,
      form_signed_date_time: terms_and_conditions_accepted.created_at,
      terms_version: terms_and_conditions_accepted.terms_and_conditions.version
    }
  end

  def user
    @user ||= User.find(user_uuid.tr('-',''))
  end

  # User's profile contains a list of VHA facility-specific identifiers.
  # Facilities in the defined range are treating facilities, indicating
  # that the user is a VA patient.
  def va_patient?
    facilities = user&.va_profile&.vha_facility_ids
    facilities.to_a.any? { |f| f.to_i.between?(*PATIENT_FACILITY_RANGE) }
  end

  def veteran?
    # TODO: this field is derived from eMIS and might have pending ATO considerations for us to use it.
    true
  end

  def create_mhv_account!
    if may_register?
      client_response = mhv_ac_client.post_register(params_for_registration)
      if client_response[:api_completion_status] == 'Successful'
        user.va_profile.mhv_ids = [client_response[:correlation_id].to_s]
        user.instance_variable_get(:@mvi).save
        self.registered_at = Time.current
        register!
      end
    end
  # TODO: handle/log exceptions more carefully
  rescue => e
    fail_register!
    log_exception_to_sentry(e)
    raise e
  end

  def upgrade_mhv_account!
    if may_upgrade?
      client_response = mhv_ac_client.post_upgrade(params_for_upgrade)
      if client_response[:status] == 'success'
        self.upgraded_at = Time.current
        upgrade!
      end
    end
  # TODO: handle/log exceptions more carefully
  rescue Common::Exceptions::BackendServiceException => e
    if e.original_body['code'] == 155
      upgrade! # without updating the timestamp since account was not created at vets.gov
    else
      fail_upgrade!
      log_exception_to_sentry(e)
      raise e
    end
  rescue => e
    fail_upgrade!
    log_exception_to_sentry(e)
    raise e
  end

  def mhv_ac_client
    @mhv_ac_client ||= MHVAC::Client.new
  end

  def previously_upgraded?
    eligible? && upgraded_at?
  end

  def previously_registered?
    eligible? && registered_at?
  end

  def setup
    raise StandardError, 'You must use find_or_initialize_by(user_uuid: #)' if user_uuid.nil?
    if beta_enabled?(user_uuid, 'health_account')
      check_eligibility
      check_terms_acceptance if may_check_terms_acceptance?
    end
  end
end
