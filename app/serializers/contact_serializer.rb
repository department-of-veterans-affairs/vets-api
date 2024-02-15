# frozen_string_literal: true

class ContactSerializer < ActiveModel::Serializer
  type :contact

  attributes(
    :contact_type,
    :given_name,
    :middle_name,
    :family_name,
    :relationship,
    :address_line1,
    :address_line2,
    :address_line3,
    :city,
    :state,
    :zip_code,
    :primary_phone
  )

  def id
    object.contact_type
  end
end
