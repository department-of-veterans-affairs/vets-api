# frozen_string_literal: true

FactoryBot.define do
  factory :pagerduty_service, class: 'PagerDuty::Models::Service' do
    service { 'Vet360' }
    status { PagerDuty::Models::Service::ACTIVE }
    last_incident_timestamp { Time.current.iso8601 }
  end
end
