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
      authn_context: object.authn_context
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
    !object.mhv_account.needs_terms_acceptance?
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
    return [] unless auth.authorized?(:profile, :list_prefills?)
    FormProfile.prefill_enabled_forms
  end

  def services
    auth.authorized_services
  end

  private

  def auth
    @auth ||= Authorization.new(object)
  end
end
