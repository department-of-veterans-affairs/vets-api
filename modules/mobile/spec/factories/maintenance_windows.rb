# frozen_string_literal: true

FactoryBot.define do
  factory :mobile_maintenance_lighthouse_first, class: '::MaintenanceWindow' do
    pagerduty_id { 'PHQI9WA' }
    external_service { 'lighthouse' }
    start_time { '2021-05-25 21:33:39' }
    end_time { '2021-05-25 22:33:39' }
    created_at { '2021-05-24 12:15:17' }
    description { 'lighthouse is down' }
  end

  factory :mobile_maintenance_lighthouse_second, class: '::MaintenanceWindow' do
    pagerduty_id { 'PHQI9WB' }
    external_service { 'lighthouse' }
    start_time { '2021-05-26 21:33:39' }
    end_time { '2021-05-26 22:33:39' }
    created_at { '2021-05-25 12:15:17' }
    description { 'lighthouse is down' }
  end

  factory :mobile_maintenance_lighthouse_third, class: '::MaintenanceWindow' do
    pagerduty_id { 'PHQI9WC' }
    external_service { 'lighthouse' }
    start_time { '2021-05-27 21:33:39' }
    end_time { '2021-05-27 22:33:39' }
    created_at { '2021-05-26 12:15:17' }
    description { 'lighthouse is down' }
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

  factory :mobile_maintenance_bgs_first, class: '::MaintenanceWindow' do
    pagerduty_id { 'PHA6DOA' }
    external_service { 'bgs' }
    start_time { '2021-05-25 23:33:39' }
    end_time { '2021-05-26 01:45:00' }
    created_at { '2021-05-24 12:15:17' }
    description { '' }
  end

  factory :mobile_maintenance_bgs_second, class: '::MaintenanceWindow' do
    pagerduty_id { 'PHA6DOG' }
    external_service { 'bgs' }
    start_time { '2021-05-26 23:33:39' }
    end_time { '2021-05-27 01:45:00' }
    created_at { '2021-05-25 12:15:17' }
    description { '' }
  end

  factory :mobile_maintenance_vbms, class: '::MaintenanceWindow' do
    pagerduty_id { 'PXF4P0E' }
    external_service { 'vbms' }
    start_time { '2021-05-25 23:33:39' }
    end_time { '2021-05-27 01:45:00' }
    created_at { '2021-05-22 12:01:15' }
    description { '' }
  end
end
