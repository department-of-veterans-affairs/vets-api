# frozen_string_literal: true

require 'rails_helper'

describe FacilitiesApi::V2::Lighthouse::Facility, type: :model, team: :facilities do
  context 'Creating' do
    let(:attributes) do
      {
        'attributes' => {
          'satisfaction' => {
            "health": {
              "primary_care_urgent": 0.8700000047683716,
              "primary_care_routine": 0.8700000047683716
            },
            "effective_date": "2024-02-08"
          },
          'wait_times' => nil
        },
        'id' => 'abc_123',
        'type' => 'va_facilities'
      }
    end

    it 'object defaults' do
      facility = FacilitiesApi::V2::Lighthouse::Facility.new(attributes)
      expect(facility.attributes).to match(
        {
          access: nil,
          active_status: nil,
          address: nil,
          classification: nil,
          detailed_services: nil,
          distance: nil,
          facility_type: nil,
          facility_type_prefix: 'abc',
          feedback: {
            "health": {
              "primary_care_urgent": 0.8700000047683716,
              "primary_care_routine": 0.8700000047683716
            },
            "effective_date": "2024-02-08"
          },
          hours: nil,
          id: 'abc_123',
          lat: nil,
          long: nil,
          mobile: nil,
          name: nil,
          operating_status: nil,
          operational_hours_special_instructions: nil,
          parent: nil,
          phone: nil,
          services: nil,
          time_zone: nil,
          type: 'va_facilities',
          unique_id: '123',
          visn: nil,
          website: nil,
          tmp_covid_online_scheduling: nil
        }
      )
    end
  end
end
