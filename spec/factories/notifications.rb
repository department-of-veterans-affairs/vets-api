# frozen_string_literal: true

FactoryBot.define do
  factory :notification do
    account
    subject { :dashboard_health_care_application_notification }

    trait :dismissed_status do
      subject { 'form_10_10ez' }
      status { 'pending_mt' }
      status_effective_at { '2019-02-25 01:22:00 UTC' }
      read_at { '2019-02-25 03:47:08 UTC' }
    end
  end
end
