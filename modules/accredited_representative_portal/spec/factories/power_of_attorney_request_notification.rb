# frozen_string_literal: true

FactoryBot.define do
  factory :power_of_attorney_request_notification,
          class: 'AccreditedRepresentativePortal::PowerOfAttorneyRequestNotification' do
    association :power_of_attorney_request, factory: :power_of_attorney_request
    notification_id { nil }
    type { AccreditedRepresentativePortal::PowerOfAttorneyRequestNotification::PERMITTED_TYPES.sample }

    trait :with_va_notify_notification do
      association :va_notify_notification, factory: :notification
    end
  end
end
