# frozen_string_literal: true

class Lighthouse::HCC::InvoiceSerializer
  include JSONAPI::Serializer

  set_type :medical_copays
  set_key_transform :camel_lower
  set_id :external_id

  attributes :url,
             :facility,
             :city,
             :external_id,
             :latest_billing_ref,
             :date,
             :current_balance,
             :previous_balance,
             :previous_unpaid_balance
end
