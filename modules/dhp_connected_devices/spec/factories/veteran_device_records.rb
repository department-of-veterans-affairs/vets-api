# frozen_string_literal: true

FactoryBot.define do
  factory :veteran_device_record, class: 'VeteranDeviceRecord' do
    trait :inactive do
      active { false }
    end
    icn { 'abc' }
    device_id { 123 }
  end
end
