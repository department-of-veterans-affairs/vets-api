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
            'icn' => '1234567890V123456',
            'smokingStatus' => 'Current smoker'
          },
          'header' => {
            'pageHeader' => "\u003cdiv style\u003d\"float:right;margin:0 0 5px 20px;\"\u003e\u003cimg src\u003d\"/avs/artwork/Dept_of_VA_Affairs-greyscale.png\" width\u003d\"205\" height\u003d\"42\" alt\u003d\"Department of Veterans Affairs\"\u003e\u003c/div\u003e\u003cdiv style\u003d\"font-size:1.8em;font-weight:bold;\"\u003eAfter Visit Summary\u003c/div\u003e\u003cdiv style\u003d\"font-size:0.9em;font-weight:bold;\"\u003ePatient,Test\u003c/div\u003e\u003cdiv style\u003d\"font-size:0.9em;\"\u003eDOB: 01/01/1950 (74y)\u003c/div\u003e\u003cdiv style\u003d\"font-size:0.9em;\"\u003eVisit date: February 07, 2024\u003c/div\u003e\u003cdiv style\u003d\"font-size:0.9em;\"\u003eDate generated: February 08, 2024 11:06\u003c/div\u003e\u003cdiv style\u003d\"font-size:0.9em;\"\u003eVEHU DIVISION\u003c/div\u003e", 'stationNo' => '500', 'timeZone' => 'US/Pacific' # rubocop:disable Layout/LineLength
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
          },
          'medChangesSummary' => {
            discontinuedMeds: [
              'ACARBOSE 50MG TAB - take one-half tablet by mouth every morning'
            ],
            newMedications: [
              'AMOXYCILLIN - take 10mL morning and evening for 10 days',
              'DIASTIX STRIPS (100S) - use 1 strip for testing as directed as directed'
            ],
            changedMedications: nil
          }
        }
      }
    end

    let(:attributes_missing_data) do
      {
        'sid' => 'abc_123',
        'appointmentIens' => ['123'],
        'generatedDate' => '2020-01-01T00:00:00Z',
        'data' => {
          'patientInfo' => { 'icn' => '1234567890V123456' },
          'header' => { 'stationNo' => '500', 'timeZone' => 'US/Pacific' }
        }
      }
    end

    it 'object defaults' do
      after_visit_summary = Avs::V0::AfterVisitSummary.new(attributes)
      expect(after_visit_summary.attributes.deep_symbolize_keys).to match(
        {
          id: 'abc_123',
          icn: '1234567890V123456',
          meta: {
            generated_date: '2020-01-01T00:00:00Z',
            page_header: "After Visit Summary\nPatient,Test\nDOB: 01/01/1950 (74y)\nVisit date: February 07, 2024\nDate generated: February 08, 2024 11:06\nVEHU DIVISION", # rubocop:disable Layout/LineLength
            station_no: '500',
            time_zone: 'US/Pacific'
          },
          patient_info: {
            smoking_status: 'Current smoker'
          },
          appointment_iens: ['123'],
          clinics_visited: [],
          providers: [],
          reason_for_visit: [],
          diagnoses: [],
          vitals: [],
          orders: [],
          procedures: [],
          immunizations: [],
          appointments: [],
          patient_instructions: nil,
          patient_education: nil,
          pharmacy_terms: [],
          primary_care_providers: [],
          primary_care_team: nil,
          primary_care_team_members: [],
          problems: [],
          clinical_reminders: [],
          clinical_services: [],
          allergies_reactions: nil,
          clinic_medications: [],
          va_medications: [],
          nonva_medications: [],
          med_changes_summary: {
            discontinuedMeds: [
              'ACARBOSE 50MG TAB - take one-half tablet by mouth every morning'
            ],
            newMedications: [
              'AMOXYCILLIN - take 10mL morning and evening for 10 days',
              'DIASTIX STRIPS (100S) - use 1 strip for testing as directed as directed'
            ],
            changedMedications: nil
          },
          lab_results: [],
          radiology_reports1_yr: nil,
          more_help_and_information: nil,
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

    it 'missing data' do
      after_visit_summary = Avs::V0::AfterVisitSummary.new(attributes_missing_data)
      expect(after_visit_summary.attributes.deep_symbolize_keys).to match(
        {
          id: 'abc_123',
          icn: '1234567890V123456',
          meta: {
            generated_date: '2020-01-01T00:00:00Z',
            page_header: nil,
            station_no: '500',
            time_zone: 'US/Pacific'
          },
          patient_info: {
            smoking_status: ''
          },
          appointment_iens: ['123'],
          clinics_visited: [],
          providers: [],
          reason_for_visit: [],
          diagnoses: [],
          vitals: [],
          orders: [],
          procedures: [],
          immunizations: [],
          appointments: [],
          patient_instructions: nil,
          patient_education: nil,
          pharmacy_terms: [],
          primary_care_providers: [],
          primary_care_team: nil,
          primary_care_team_members: [],
          problems: [],
          clinical_reminders: [],
          clinical_services: [],
          allergies_reactions: nil,
          clinic_medications: [],
          va_medications: [],
          nonva_medications: [],
          med_changes_summary: nil,
          lab_results: [],
          radiology_reports1_yr: nil,
          more_help_and_information: nil,
          discrete_data: nil
        }
      )
    end
  end
end
