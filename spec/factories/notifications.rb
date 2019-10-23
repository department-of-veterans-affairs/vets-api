# frozen_string_literal: true

FactoryBot.define do
  factory :notification do
    account
    subject { Notification::DASHBOARD_HEALTH_CARE_APPLICATION_NOTIFICATION }

    trait :dismissed_status do
      subject { Notification::FORM_10_10EZ }

      status { Notification::PENDING_MT }
      status_effective_at { '2019-02-25 01:22:00 UTC' }
      read_at { '2019-02-25 03:47:08 UTC' }
    end
  end
end
