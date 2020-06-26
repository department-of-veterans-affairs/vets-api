# frozen_string_literal: true

class PPMS::ProviderSerializer
  include FastJsonapi::ObjectSerializer

  # attributes :acc_new_patients,
  #            :email,
  #            :fax,
  #            :gender,
  #            :name,
  #            :pos_codes,
  #            :unique_id,
  #            :address,
  #            :caresite_phone,
  #            :lat,
  #            :long,
  #            :phone,
  #            :pref_contact,
  #            :specialty

  attribute :acc_new_patients

  attribute :address do |object|
    addr = {
        street: object.address_street,
        city: object.address_city,
        state: object.address_state_province,
        zip: object.address_postal_code
      }
    if addr.values.all?
      addr
    else
      {}
    end
  end

  attribute :caresite_phone do |object|
    object.caresite_phone
  end

  attribute :email

  attribute :fax

  attribute :gender

  attribute :lat do |object|
    object.latitude
  end

  attribute :long do |object|
    object.longitude
  end

  attribute :name do |object|
    possible_name =
      case object.provider_type
      when /GroupPracticeOrAgency/i
        object.care_site
      else
        object.provider_name
      end
    [possible_name, object.name].find(&:present?)
  end

  attribute :phone do |object|
    object.main_phone
  end

  attribute :pos_codes

  attribute :pref_contact do |object|
    object.contact_method
  end

  attribute :specialty do |object|
    object.provider_specialties.map do |specialty|
      {
        name: specialty['SpecialtyName'],
        desc: specialty['SpecialtyDescription']
      }
    end
  end

  attribute :unique_id do |object|
    object.provider_identifier
  end

end
