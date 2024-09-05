# frozen_string_literal: true

FactoryBot.define do
  factory :backend_status do
    is_available { true }
    name { 'gibs' }
    service_id { 'appeals' }
    uptime_remaining { 39_522 }
  end
end
