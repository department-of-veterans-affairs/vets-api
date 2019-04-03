# frozen_string_literal: true

FactoryBot.define do
  factory :session_activity do
    originating_request_id { SecureRandom.uuid }
    originating_ip_address { '200.200.200.200' }
    name 'signup'
    status 'incomplete'
    user_uuid { SecureRandom.uuid }
    sign_in_service_name 'idme'
    sign_in_account_type nil
    multifactor_enabled false
    idme_verified false
    duration 200
    additional_data {}
  end
end
