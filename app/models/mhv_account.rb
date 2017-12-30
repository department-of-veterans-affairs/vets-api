# frozen_string_literal: true

class MhvAccount < ActiveRecord::Base
  include AASM

  TERMS_AND_CONDITIONS_NAME = 'mhvac'
  # Everything except existing and ineligible accounts should be able to transition to :needs_terms_acceptance
  ALL_STATES = %i(
    unknown
    needs_terms_acceptance
    existing
    ineligible
    registered
    upgraded
    register_failed
    upgrade_failed
  ).freeze

  ADDRESS_ATTRS = %w(street city state postal_code country).freeze
  UNKNOWN_ADDRESS = {
    address1: 'Unknown Address',
    city: 'Washington',
    state: 'DC',
    zip: '20571',
    country: 'USA'
  }.freeze
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
      transitions from: ALL_STATES - [:existing, :ineligible],
                  to: :needs_terms_acceptance, unless: :terms_and_conditions_accepted?
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

  def eligible?
    user.loa3? && va_patient?
  end

  def terms_and_conditions_accepted?
    terms_and_conditions_accepted.present?
  end

  def previously_registered?
    eligible? && registered_at?
  end

  def previously_upgraded?
    eligible? && upgraded_at?
  end

  def preexisting_account?
    user&.mhv_correlation_id.present? && !previously_registered?
  end

  def accessible?
    (user.loa3? || user.authn_context.include?('myhealthevet')) && (upgraded? || existing?)
  end

  def params_for_registration
    {
      icn: user.icn,
      is_patient: va_patient?,
      is_veteran: veteran?,
      province: nil, # TODO: We need to determine if this is something that could actually happen (non USA)
      email: user.email,
      home_phone: user.va_profile&.home_phone,
      sign_in_partners: 'VETS.GOV',
      terms_version: terms_and_conditions_accepted.terms_and_conditions.version,
      terms_accepted_date: terms_and_conditions_accepted.created_at
    }.merge!(address_params)
  end

  def params_for_upgrade
    {
      user_id: user.mhv_correlation_id,
      form_signed_date_time: terms_and_conditions_accepted.created_at,
      terms_version: terms_and_conditions_accepted.terms_and_conditions.version
    }
  end

  private

  def terms_and_conditions_accepted
    @terms_and_conditions_accepted ||=
      TermsAndConditionsAcceptance.joins(:terms_and_conditions)
                                  .includes(:terms_and_conditions)
                                  .where(terms_and_conditions: { latest: true, name: TERMS_AND_CONDITIONS_NAME })
                                  .where(user_uuid: user_uuid).limit(1).first
  end

  def address_params
    if user.va_profile&.address.present? &&
       ADDRESS_ATTRS.all? { |attr| user.va_profile.address[attr].present? }
      return {
        address1: user.va_profile.address.street,
        city: user.va_profile.address.city,
        state: user.va_profile.address.state,
        zip: user.va_profile.address.postal_code,
        country: user.va_profile.address.country
      }
    end
    UNKNOWN_ADDRESS
  end

  def user
    @user ||= User.find(user_uuid)
  end

  # User's profile contains a list of VHA facility-specific identifiers.
  # Facilities in the defined range are treating facilities, indicating
  # that the user is a VA patient.
  def va_patient?
    facilities = user&.va_profile&.vha_facility_ids
    facilities.to_a.any? do |f|
      Settings.mhv.facility_range.any? { |range| f.to_i.between?(*range) }
    end
  end

  def veteran?
    user.veteran?
  rescue
    false
  end

  def setup
    raise StandardError, 'You must use find_or_initialize_by(user_uuid: #)' if user_uuid.nil?
    check_eligibility unless registered? || upgraded?
    check_terms_acceptance if may_check_terms_acceptance?
  end
end
