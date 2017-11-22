# frozen_string_literal: true
FactoryBot.define do
  factory :access_satisfaction, class: 'FacilitySatisfaction' do
    station_number '648'
    metrics do
      {
        primary_care_urgent: 0.71890521049499512,
        primary_care_routine: 0.81882423162460327,
        specialty_care_routine: 0.79339683055877686,
        specialty_care_urgent: 0.68941879272460938
      }
    end
    source_updated '2017-03-24T21:30:58'
    local_updated '2017-06-12T21:04:54Z'
  end

  factory :access_wait_time, class: 'FacilityWaitTime' do
    station_number '648'
    metrics do
      {
        primary_care: { 'new' => 35.0, 'established' => 9.0 },
        mental_health: { 'new' => 17.0, 'established' => 1.0 },
        audiology: { 'new' => 29.0, 'established' => 17.0 },
        womens_health: { 'new' => nil, 'established' => 11.0 },
        opthalmology: { 'new' => 21.0, 'established' => 8.0 },
        urology_clinic: { 'new' => 20.0, 'established' => 7.0 }
      }
    end
    source_updated '2017-03-31T00:00:00'
    local_updated  '2017-06-12T21:04:58Z'
  end
end
