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

  delegate :va_profile, to: :object

  def services
    service_list = [
      BackendServices::FACILITIES,
      BackendServices::HCA,
      BackendServices::EDUCATION_BENEFITS
    ]
    service_list += [BackendServices::RX, BackendServices::MESSAGING] if object.can_access_mhv?
    service_list << BackendServices::EVSS_BENEFITS if object.can_access_evss?
    service_list << BackendServices::USER_PROFILE if object.can_access_user_profile?
    service_list
  end
end
