# frozen_string_literal: true

FactoryBot.define do
  factory :tud_account_availability_log, class: 'TestUserDashboard::TudAccountAvailabilityLog' do
    account_uuid { nil }
    checkout_time { Time.now.utc }
    checkin_time { nil }
    has_checkin_error { nil }
    is_manual_checkin { nil }
  end
end
