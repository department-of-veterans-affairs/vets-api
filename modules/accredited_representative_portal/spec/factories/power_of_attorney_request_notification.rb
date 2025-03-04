# frozen_string_literal: true

FactoryBot.define do
  factory :power_of_attorney_request_notification,
          class: 'AccreditedRepresentativePortal::PowerOfAttorneyRequestNotification' do
    association :power_of_attorney_request, factory: :power_of_attorney_request
    association :va_notify_notification, factory: :notification
    type { AccreditedRepresentativePortal::PowerOfAttorneyRequestNotification::PERMITTED_TYPES.sample }
  end
end
