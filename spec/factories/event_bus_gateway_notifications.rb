# frozen_string_literal: true

FactoryBot.define do
  factory :event_bus_gateway_notification do
    association :user_account
    template_id { SecureRandom.uuid }
    va_notify_id { SecureRandom.uuid }
    attempts { 1 }
  end
end
