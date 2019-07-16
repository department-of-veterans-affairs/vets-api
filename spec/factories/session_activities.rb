# frozen_string_literal: true

FactoryBot.define do
  factory :session_activity do
    originating_request_id { SecureRandom.uuid }
    originating_ip_address { '0.0.0.0' }
    name 'idme'
    status 'incomplete'
    user_uuid nil
    sign_in_service_name nil
    sign_in_account_type nil
    multifactor_enabled nil
    idme_verified nil
    duration nil
    additional_data { { originating_user_agent: 'Rails Testing' } }
  end
end
