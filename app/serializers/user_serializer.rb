# frozen_string_literal: true
require 'backend_services'

class UserSerializer < ActiveModel::Serializer
  attributes :services, :profile, :va_profile

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
    status = object.va_profile[:status]
    return { status: status } unless status == 'OK'
    {
      status: object.va_profile[:status],
      birth_date: object.va_profile[:birth_date],
      family_name: object.va_profile[:family_name],
      gender: object.va_profile[:gender],
      given_names: object.va_profile[:given_names]
    }
  end

  def services
    service_list = [
      BackendServices::FACILITIES,
      BackendServices::HCA,
      BackendServices::EDUCATION_BENEFITS
    ]
    service_list += BackendServices::MHV_BASED_SERVICES if object.can_access_mhv?
    service_list << BackendServices::EVSS_CLAIMS if object.can_access_evss?
    service_list << BackendServices::USER_PROFILE if object.can_access_user_profile?
    service_list
  end
end
