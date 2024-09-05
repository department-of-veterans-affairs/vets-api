# frozen_string_literal: true

FactoryBot.define do
  factory :extract_status do
    created_on { Time.current.iso8601 }
    extract_type { 'DodMilitaryService' }
    last_updated { Time.current.iso8601 }
    station_number { 123 }
    status { 'OK' }
  end
end
