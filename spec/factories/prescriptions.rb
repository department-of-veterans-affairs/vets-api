# frozen_string_literal: true

FactoryBot.define do
  factory :prescription do
    prescription_id       { 1_435_525 }
    refill_status         { 'active' }
    refill_date           { 'Thu, 21 Apr 2016 00:00:00 EDT' }
    refill_submit_date    { 'Tue, 26 Apr 2016 00:00:00 EDT' }
    refill_remaining      { 9 }
    facility_name         { 'ABC1223' }
    ordered_date          { 'Tue, 29 Mar 2016 00:00:00 EDT' }
    quantity              { '10' }
    expiration_date       { 'Thu, 30 Mar 2017 00:00:00 EDT' }
    prescription_number   { '2719324' }
    prescription_name     { 'Drug 1 250MG TAB' }
    dispensed_date        { 'Thu, 21 Apr 2016 00:00:00 EDT' }
    station_number        { '23' }
    is_refillable         { true }
    is_trackable          { false }

    trait :with_api_name do
      facility_api_name { 'Dayton Medical Center' }
    end
  end
end
