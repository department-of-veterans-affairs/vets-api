# frozen_string_literal: true

class PPMS::ProviderSerializer
  include FastJsonapi::ObjectSerializer

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

  attribute :caresite_phone, &:caresite_phone

  attribute :email

  attribute :fax

  attribute :gender

  attribute :lat, &:latitude

  attribute :long, &:longitude

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

  attribute :phone, &:main_phone

  attribute :pos_codes

  attribute :pref_contact, &:contact_method

  attribute :unique_id, &:provider_identifier

  has_many :specialties
end
