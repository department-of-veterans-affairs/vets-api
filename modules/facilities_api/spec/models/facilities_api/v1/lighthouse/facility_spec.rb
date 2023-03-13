# frozen_string_literal: true

require 'rails_helper'

describe FacilitiesApi::V1::Lighthouse::Facility, type: :model, team: :facilities do
  context 'Creating' do
    let(:attributes) do
      {
        'attributes' => {
          'satisfaction' => nil,
          'wait_times' => nil
        },
        'id' => 'abc_123',
        'type' => nil
      }
    end

    it 'object defaults' do
      facility = FacilitiesApi::V1::Lighthouse::Facility.new(attributes)
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
          feedback: nil,
          hours: nil,
          id: 'abc_123',
          lat: nil,
          long: nil,
          mobile: nil,
          name: nil,
          operating_status: nil,
          operational_hours_special_instructions: nil,
          phone: nil,
          services: nil,
          type: nil,
          unique_id: '123',
          visn: nil,
          website: nil,
          tmp_covid_online_scheduling: nil
        }
      )
    end
  end
end
