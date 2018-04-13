# frozen_string_literal: true

require 'backend_services'
require 'common/client/concerns/service_status'

class UserSerializer < ActiveModel::Serializer
  include Common::Client::ServiceStatus

  attributes :services, :profile, :va_profile, :veteran_status, :mhv_account_state, :health_terms_current,
             :in_progress_forms, :prefills_available

  def id
    nil
  end

  def profile
    {
      email: object.email,
      first_name: object.first_name,
      middle_name: object.middle_name,
      last_name: object.last_name,
      birth_date: object.birth_date,
      gender: object.gender,
      zip: object.zip,
      last_signed_in: object.last_signed_in,
      loa: object.loa,
      multifactor: object.multifactor,
      verified: object.loa3?,
      authn_context: object.authn_context
    }
  end

  def vet360_contact_information
    person = object.vet360_contact_info

    {
      email: person.email&.details,
      residential_address: person.residential_address&.details,
      mailing_address: person.mailing_address&.details,
      mobile_phone: person.mobile_phone&.details,
      home_phone: person.home_phone&.details,
      work_phone: person.work_phone&.details,
      temporary_phone: person.temporary_phone&.details,
      fax_number: person.fax_number&.details
    }
  end

  def va_profile
    status = object.va_profile_status
    return { status: status } unless status == RESPONSE_STATUS[:ok]
    {
      status: status,
      birth_date: object.va_profile.birth_date,
      family_name: object.va_profile.family_name,
      gender: object.va_profile.gender,
      given_names: object.va_profile.given_names
    }
  end

  def veteran_status
    {
      status: RESPONSE_STATUS[:ok],
      is_veteran: object.veteran?
    }
  rescue EMISRedis::VeteranStatus::NotAuthorized
    { status: RESPONSE_STATUS[:not_authorized] }
  rescue EMISRedis::VeteranStatus::RecordNotFound
    { status: RESPONSE_STATUS[:not_found] }
  rescue StandardError
    { status: RESPONSE_STATUS[:server_error] }
  end

  def health_terms_current
    object.mhv_account.terms_and_conditions_accepted?
  end

  def in_progress_forms
    object.in_progress_forms.map do |form|
      {
        form: form.form_id,
        metadata: form.metadata,
        last_updated: form.updated_at.to_i
      }
    end
  end

  def prefills_available
    return [] unless object.identity.present? && object.can_access_prefill_data?
    FormProfile.prefill_enabled_forms
  end

  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def services
    service_list = [
      BackendServices::FACILITIES,
      BackendServices::HCA,
      BackendServices::EDUCATION_BENEFITS
    ]
    service_list << BackendServices::RX if object.authorize :mhv_prescriptions, :access?
    service_list << BackendServices::MESSAGING if object.authorize :mhv_messaging, :access?
    service_list << BackendServices::HEALTH_RECORDS if object.authorize :mhv_health_records, :access?
    service_list << BackendServices::MHV_AC if object.authorize :mhv_account_creation, :access?
    service_list << BackendServices::EVSS_CLAIMS if object.authorize :evss, :access?
    service_list << BackendServices::USER_PROFILE if object.can_access_user_profile?
    service_list << BackendServices::APPEALS_STATUS if object.authorize :appeals, :access?
    service_list << BackendServices::SAVE_IN_PROGRESS if object.can_save_partial_forms?
    service_list << BackendServices::FORM_PREFILL if object.can_access_prefill_data?
    service_list << BackendServices::ID_CARD if object.can_access_id_card?
    service_list << BackendServices::IDENTITY_PROOFED if object.identity_proofed?
    service_list += BetaRegistration.where(user_uuid: object.uuid).pluck(:feature) || []
    service_list
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
end
