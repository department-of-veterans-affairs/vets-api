# frozen_string_literal: true
require 'backend_services'

class UserSerializer < ActiveModel::Serializer
  attributes :services, :profile, :va_profile

  def id
    nil
  end

  def profile
    {
      email:          object.email,
      first_name:     object.first_name,
      middle_name:    object.middle_name,
      last_name:      object.last_name,
      birth_date:     object.birth_date,
      gender:         object.gender,
      zip:            object.zip,
      last_signed_in: object.last_signed_in,
      loa:            object.loa
    }
  end

  def va_profile
    {
      birth_date:   object.mvi.nil? ? nil : object.mvi['birth_date'],
      family_name:  object.mvi.nil? ? nil : object.mvi['family_name'],
      gender:       object.mvi.nil? ? nil : object.mvi['gender'],
      given_names:  object.mvi.nil? ? nil : object.mvi['given_names'],
      status:       object.mvi.nil? ? nil : object.mvi['status']
    }
  end

  def services
    [
      BackendServices::FACILITIES,
      BackendServices::HCA,
      BackendServices::EDUCATION_BENEFITS
    ].tap do |service_list|
      service_list += [BackendServices::RX, BackendServices::MESSAGING] if object.can_access_mhv?
      service_list << BackendServices::DISABILITY_BENEFITS if object.can_access_evss?
      service_list << BackendServices::USER_PROFILE if object.can_access_user_profile?
    end
  end
end
