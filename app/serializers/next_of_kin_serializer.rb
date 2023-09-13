# frozen_string_literal: true

class NextOfKinSerializer < ActiveModel::Serializer
  attributes(
    :given_name,
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
    object.tx_audit_id
  end
end
