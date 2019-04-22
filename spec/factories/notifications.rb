# frozen_string_literal: true

FactoryBot.define do
  factory :notification do
    account
    subject { :dashboard_health_care_application_notification }
  end
end
