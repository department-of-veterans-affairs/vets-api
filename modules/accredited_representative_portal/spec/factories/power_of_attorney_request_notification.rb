# frozen_string_literal: true

FactoryBot.define do
  factory :power_of_attorney_request_notification,
          class: 'AccreditedRepresentativePortal::PowerOfAttorneyRequestNotification' do
    association :power_of_attorney_request, factory: :power_of_attorney_request
    association :va_notify_notification, factory: :notification
    notification_type { AccreditedRepresentativePortal::PowerOfAttorneyRequestNotification::PERMITTED_TYPES.sample }

    trait :requested do
      notification_type { 'requested_poa' }
    end

    trait :declined do
      notification_type { 'declined_poa' }
    end

    trait :expiring do
      notification_type { 'expiring_poa' }
    end

    trait :expired do
      notification_type { 'expired_poa' }
    end
  end
end
