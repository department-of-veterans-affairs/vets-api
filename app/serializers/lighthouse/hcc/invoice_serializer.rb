# frozen_string_literal: true

class Lighthouse::HCC::InvoiceSerializer
  include JSONAPI::Serializer

  set_type :medical_copays
  set_key_transform :camel_lower
  set_id :external_id

  attributes :url,
             :facility,
             :facility_id,
             :city,
             :external_id,
             :latest_billing_ref,
             :current_balance,
             :previous_balance,
             :previous_unpaid_balance,
             :last_updated_at
end
