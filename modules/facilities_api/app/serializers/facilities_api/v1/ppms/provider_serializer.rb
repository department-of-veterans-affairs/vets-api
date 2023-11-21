# frozen_string_literal: true

module FacilitiesApi
  class V1::PPMS::ProviderSerializer
    include JSONAPI::Serializer

    set_key_transform :camel_lower

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

    attribute :pos_codes do |object|
      if object.pos_codes.is_a?(Array)
        object.pos_codes.first
      else
        object.pos_codes
      end
    end

    attribute :pref_contact, &:contact_method

    attribute :trainings

    attribute :unique_id, &:provider_identifier
  end
end
