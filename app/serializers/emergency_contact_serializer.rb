# frozen_string_literal: true

class EmergencyContactSerializer < ActiveModel::Serializer
  type :emergency_contact

  attributes(
    :contact_type,
    :given_name,
    :family_name,
    :primary_phone
  )

  def id
    object.tx_audit_id
  end
end
