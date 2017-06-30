# frozen_string_literal: true
require 'backend_services'
require 'common/client/concerns/service_status'
require 'beta_switch'

class UserSerializer < ActiveModel::Serializer
  include Common::Client::ServiceStatus
  include BetaSwitch

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
      loa: object.loa
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
  rescue VeteranStatus::NotAuthorized
    { status: RESPONSE_STATUS[:not_authorized] }
  rescue VeteranStatus::RecordNotFound
    { status: RESPONSE_STATUS[:not_found] }
  rescue StandardError
    { status: RESPONSE_STATUS[:server_error] }
  end

  def health_terms_current
    if beta_enabled?(object.uuid, 'health_account')
      !object.mhv_account.needs_terms_acceptance?
    else
      # Don't prompt terms for non-beta users
      true
    end
  end

  def in_progress_forms
    object.in_progress_forms.map do |form|
      { form: form.form_id, last_updated: form.updated_at.to_i }
    end
  end

  def prefills_available
    FeatureFlipper.enable_prefill?(object) ? FormProfile::MAPPINGS : []
  end

  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def services
    service_list = [
      BackendServices::FACILITIES,
      BackendServices::HCA,
      BackendServices::EDUCATION_BENEFITS
    ]
    if beta_enabled?(object.uuid, 'health_account')
      service_list += BackendServices::MHV_BASED_SERVICES if object.mhv_account_eligible?
    elsif object.loa3? && object.mhv_correlation_id.present?
      # Allow access for existing MHV accounts for non-beta users
      service_list += BackendServices::MHV_BASED_SERVICES
    end
    service_list << BackendServices::EVSS_CLAIMS if object.can_access_evss?
    service_list << BackendServices::USER_PROFILE if object.can_access_user_profile?
    service_list << BackendServices::APPEALS_STATUS if beta_enabled?(object.uuid, 'appeals_status') &&
                                                       object.can_access_appeals?
    service_list
  end
end
