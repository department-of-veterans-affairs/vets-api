# frozen_string_literal: true

class ProviderSerializer < ActiveModel::Serializer
  type 'cc_provider'
  def id
    "ccp_#{object.ProviderIdentifier}"
  end

  def unique_id
    object.ProviderIdentifier
  end

  def name
    object.Name
  end

  def address
    { street: object.AddressStreet, city: object.AddressCity,
      state: object.AddressStateProvince,
      zip: object.AddressPostalCode }
  end

  def phone
    object.MainPhone
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
    object.ProviderSpecialties.map { |specialty| specialty['SpecialtyName'] }
  end

  attributes :unique_id, :name, :address, :phone, :fax,
             :pref_contact, :acc_new_patients, :gender, :specialty
end
