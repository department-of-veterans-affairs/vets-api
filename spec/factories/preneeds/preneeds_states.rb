# frozen_string_literal: true
FactoryBot.define do
  factory :preneeds_state, class: Preneeds::State do
    sequence(:code) { |n| ('A'.ord + n / 26).chr + ('A'.ord + (n - 1) % 26).chr }
    sequence(:name) { |n| ('A'.ord + n / 26).chr + ('A'.ord + (n - 1) % 26).chr + ' name' }
    first_five_zip '12345'
    last_five_zip '67890'
    lower_indicator 'N'
  end
end
