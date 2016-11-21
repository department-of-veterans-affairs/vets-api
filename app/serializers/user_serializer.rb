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
      loa_highest: object.loa_highest
    }
  end

  def va_profile
    Mvi.from_user(object).va_profile(instance_options[:session])
  end

  def services
    service_list = [
      BackendServices::FACILITIES,
      BackendServices::HCA,
      BackendServices::EDUCATION_BENEFITS
    ]
    service_list += [BackendServices::RX, BackendServices::MESSAGING] if object.can_access_mhv?(instance_options[:session])
    service_list << BackendServices::DISABILITY_BENEFITS if object.can_access_evss?
    service_list << BackendServices::USER_PROFILE if object.can_access_user_profile?(instance_options[:session])
    service_list
  end
end
