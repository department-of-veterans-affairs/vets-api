# frozen_string_literal: true

FactoryBot.define do
  factory :mobile_maintenance_evss, class: '::MaintenanceWindow' do
    pagerduty_id { 'PHQI9WA' }
    external_service { 'evss' }
    start_time { '2021-05-25 21:33:39' }
    end_time { '2021-05-26 00:33:39' }
    created_at { '2021-05-24 12:15:17' }
    description { 'evss is down' }
  end

  factory :mobile_maintenance_mpi, class: '::MaintenanceWindow' do
    pagerduty_id { 'PHQI9WB' }
    external_service { 'mpi' }
    start_time { '2021-05-25 23:33:39' }
    end_time { '2021-05-26 01:45:00' }
    created_at { '2021-05-24 12:15:17' }
    description { 'mpi is down' }
  end

  factory :mobile_maintenance_dslogon, class: '::MaintenanceWindow' do
    pagerduty_id { 'PHA6DOW' }
    external_service { 'dslogon' }
    start_time { '2021-05-25 23:33:39' }
    end_time { '2021-05-26 01:45:00' }
    created_at { '2021-05-24 12:15:17' }
    description { '' }
  end

  factory :mobile_maintenance_bgs, class: '::MaintenanceWindow' do
    pagerduty_id { 'PHA6DOW' }
    external_service { 'bgs' }
    start_time { '2021-05-25 23:33:39' }
    end_time { '2021-05-26 01:45:00' }
    created_at { '2021-05-24 12:15:17' }
    description { '' }
  end
end
