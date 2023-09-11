# frozen_string_literal: true

class EmergencyContactSerializer < ActiveModel::Serializer
  attributes(
    :contact_type,
    :given_name,
    :family_name,
    :primary_phone
  )

  def id
    tx_audit_id
  end
end
