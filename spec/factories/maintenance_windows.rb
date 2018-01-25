# frozen_string_literal: true

FactoryBot.define do
  factory :maintenance_window do
    pagerduty_id 'MyString'
    external_service 'MyString'
    start_time '2017-12-20 22:55:20'
    end_time '2017-12-20 22:55:20'
    description 'MyString'
  end

  factory :maintenance_hash, class: Hash do
    initialize_with do
      {
        pagerduty_id: 'ABCDEF',
        external_service: 'emis',
        start_time: '2017-12-20 22:55:20',
        end_time: '2017-12-20 22:55:20',
        description: 'Outage'
      }
    end
  end

  factory :maintenance_hash_updated, class: Hash do
    initialize_with do
      {
        pagerduty_id: 'ABCDEF',
        external_service: 'emis',
        start_time: '2017-12-20 22:55:20',
        end_time: '2017-12-30 22:55:20',
        description: 'New Description'
      }
    end
  end

  factory :maintenance_hash_multi1, class: Hash do
    initialize_with do
      {
        pagerduty_id: 'ABC123',
        external_service: 'mvi',
        start_time: '2017-12-21 22:55:20',
        end_time: '2017-12-21 22:55:20',
        description: 'Outage'
      }
    end
  end

  factory :maintenance_hash_multi2, class: Hash do
    initialize_with do
      {
        pagerduty_id: 'ABC123',
        external_service: 'emis',
        start_time: '2017-12-21 22:55:20',
        end_time: '2017-12-21 22:55:20',
        description: 'Outage'
      }
    end
  end

  factory :maintenance_hash_with_message, class: Hash do
    initialize_with do
      {
        pagerduty_id: 'ABCDEF',
        external_service: 'emis',
        start_time: '2017-12-20 22:55:20',
        end_time: '2017-12-20 22:55:20',
        description: 'Outage\nUSER_MESSAGE: Sorry, EMIS is unavailable RN\nTry again later  '
      }
    end
  end
end
