# frozen_string_literal: true

class ProviderSerializer < ActiveModel::Serializer
  type 'cc_provider'

  def id
    if Flipper.enabled?(:facility_locator_ppms_forced_unique_id)
      obj_id = object.ProviderHexdigest || object.ProviderIdentifier
      "ccp_#{obj_id}"
    else
      "ccp_#{object.ProviderIdentifier}"
    end
  end

  def unique_id
    object.ProviderIdentifier
  end

  def name
    possible_name =
      case object.ProviderType
      when /GroupPracticeOrAgency/i
        object.CareSite
      else
        object.ProviderName
      end
    [possible_name, object.Name].find(&:present?)
  end

  def address
    if object.AddressStreet && object.AddressCity && object.AddressStateProvince && object.AddressPostalCode
      {
        street: object.AddressStreet,
        city: object.AddressCity,
        state: object.AddressStateProvince,
        zip: object.AddressPostalCode
      }
    else
      {}
    end
  end

  def lat
    object.Latitude
  end

  def long
    object.Longitude
  end

  def email
    object.Email
  end

  def phone
    object.MainPhone
  end

  def pos_codes
    object.posCodes
  end

  def caresite_phone
    object.CareSitePhoneNumber
  end

  def fax
    object.OrganizationFax
  end

  def pref_contact
    object.ContactMethod
  end

  def acc_new_patients
    object.IsAcceptingNewPatients
  end

  def gender
    object.ProviderGender
  end

  def specialty
    object.ProviderSpecialties.map do |specialty|
      { name: specialty['SpecialtyName'],
        desc: specialty['SpecialtyDescription'] }
    end
  end

  attributes  :acc_new_patients,
              :address,
              :caresite_phone,
              :email,
              :fax,
              :gender,
              :lat,
              :long,
              :name,
              :phone,
              :pos_codes,
              :pref_contact,
              :specialty,
              :unique_id
end
