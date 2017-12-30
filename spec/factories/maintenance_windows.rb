# frozen_string_literal: true
FactoryBot.define do
  factory :maintenance_window do
    pagerduty_id 'MyString'
    external_service 'MyString'
    start_time '2017-12-20 22:55:20'
    end_time '2017-12-20 22:55:20'
    description 'MyString'
  end
end
