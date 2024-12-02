FactoryBot.define do
  factory :load_testing_test_token, class: 'LoadTesting::TestToken' do
    association :test_session, factory: :load_testing_test_session
    access_token { "test_access_token_#{SecureRandom.hex(8)}" }
    refresh_token { "test_refresh_token_#{SecureRandom.hex(8)}" }
    device_secret { "test_device_secret_#{SecureRandom.hex(8)}" }
    expires_at { 30.minutes.from_now }
  end
end 