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

    trait :with_resolution do
      after(:create) do |notification|
        create(
          :power_of_attorney_request_resolution,
          power_of_attorney_request: notification.power_of_attorney_request,
          declination_reason: :DECLINATION_OTHER
        )
      end
    end
  end
end
