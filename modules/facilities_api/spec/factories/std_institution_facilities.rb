# frozen_string_literal: true

FactoryBot.define do
  factory :std_institution_facility do
    name { 'Fake facility name' }
    station_number { '123' }
    street_state_id { 'OH' }
  end
end
