# frozen_string_literal: true

class ContactSerializer
  include JSONAPI::Serializer

  set_id :contact_type
  set_type :contact

  attributes :contact_type, :given_name, :middle_name, :family_name, :relationship,
             :address_line1, :address_line2, :address_line3, :city, :state, :zip_code, :primary_phone
end
