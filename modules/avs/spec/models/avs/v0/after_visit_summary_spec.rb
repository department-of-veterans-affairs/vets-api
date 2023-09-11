# frozen_string_literal: true

require 'rails_helper'

describe Avs::V0::AfterVisitSummary, type: :model do
  context 'Creating' do
    let(:attributes) do
      {
        'sid' => 'abc_123',
        'appointmentIens' => ['123'],
        'generatedDate' => '2020-01-01T00:00:00Z',
        'data' => {
          'patientInfo' => {
            'icn' => '1234567890V123456'
          },
          'header' => {
            'timeZone' => 'US/Pacific'
          },
          'discreteData' => {
            temp: [
              {
                T: 'DiscreteItem',
                datetime: '01/01/2023@08:23:54',
                # rubocop:disable Style/NumericLiterals
                fmDate: 3230103.082354,
                # rubocop:enable Style/NumericLiterals
                value: '99.1'
              }
            ]
          }
        }
      }
    end

    it 'object defaults' do
      after_visit_summary = Avs::V0::AfterVisitSummary.new(attributes)
      expect(after_visit_summary.attributes).to match(
        {
          id: 'abc_123',
          icn: '1234567890V123456',
          meta: {
            generated_date: '2020-01-01T00:00:00Z',
            time_zone: 'US/Pacific'
          },
          appointment_iens: ['123'],
          clinics_visited: [],
          providers: [],
          reason_for_visit: [],
          diagnoses: [],
          vitals: [],
          orders: [],
          immunizations: [],
          appointments: [],
          patient_instructions: nil,
          patient_education: nil,
          primary_care_providers: [],
          primary_care_team: nil,
          primary_care_team_members: [],
          allergies_reactions: nil,
          va_medications: [],
          lab_results: [],
          radiology_reports1_yr: nil,
          discrete_data: {
            temp: [
              {
                T: 'DiscreteItem',
                datetime: '01/01/2023@08:23:54',
                # rubocop:disable Style/NumericLiterals
                fmDate: 3230103.082354,
                # rubocop:enable Style/NumericLiterals
                value: '99.1'
              }
            ]
          }
        }
      )
    end
  end
end
