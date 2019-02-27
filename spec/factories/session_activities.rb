FactoryBot.define do
  factory :session_activity do
    originating_request_id { SecureRandom.uuid }
    name 'signup'
    status 'abandoned'
    sign_in_service_name 'idme'
    sign_in_account_type nil
    multifactor_enabled false
    idme_verified false
    duration 200
    additional_data {}
  end
end
