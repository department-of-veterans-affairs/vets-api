# frozen_string_literal: true

FactoryBot.define do
  factory :device, class: 'Device' do
    trait :fitbit do
      key { 'fitbit' }
      name { 'Fitbit' }
    end

    trait :abbott do
      key { 'abbott' }
      name { 'Libre View' }
    end
  end
end
