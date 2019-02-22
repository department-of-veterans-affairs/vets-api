# frozen_string_literal: true

FactoryBot.define do
  factory :event_log, class: 'EventLog::EventLog' do
    request_id { SecureRandom.uuid }
    type ''
    ip_address { [Faker::Internet.ip_v4_address, Faker::Internet.ip_v6_address].sample }
    state nil
    account_id nil
    description nil
    reference_class nil
    reference_id nil
    data { {} }
  end

  factory :login_init_log, parent: :event_log, class: 'EventLog::LoginInitLog' do
    type 'EventLog::LoginInitLog'
  end

  factory :login_callback_log, parent: :event_log, class: 'EventLog::LoginCallbackLog' do
    type 'EventLog::LoginCallbackLog'
  end

  factory :logout_init_log, parent: :event_log, class: 'EventLog::LogoutInitLog' do
    type 'EventLog::LogoutInitLog'
  end

  factory :logout_callback_log, parent: :event_log, class: 'EventLog::LogoutCallbackLog' do
    type 'EventLog::LogoutCallbackLog'
  end
end
