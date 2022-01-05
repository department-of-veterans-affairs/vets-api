# frozen_string_literal: true

require 'rails_helper'
require 'ostruct'
require 'fast_track/disability_compensation_job'

medication_response = {
  'resourceType' => 'Bundle',
  'type' => 'searchset',
  'total' => 2,
  'link' => [
    {
      'relation' => 'first',
      'url' => 'https://sandbox-api.va.gov/services/fhir/v0/r4/MedicationRequest?patient=1012667169V030190&page=1&_count=30'
    },
    {
      'relation' => 'self',
      'url' => 'https://sandbox-api.va.gov/services/fhir/v0/r4/MedicationRequest?patient=1012667169V030190&page=1&_count=30'
    },
    {
      'relation' => 'last',
      'url' => 'https://sandbox-api.va.gov/services/fhir/v0/r4/MedicationRequest?patient=1012667169V030190&page=1&_count=30'
    }
  ],
  'entry' => [{
    'fullUrl' => 'https://sandbox-api.va.gov/services/fhir/v0/r4/MedicationRequest/I2-JH6TLLVWUK4CMUKAUUT553H2Q57RUKLX5DBEBNMIUVS3RNOT3LRA0000',
    'resource' => {
      'resourceType' => 'MedicationRequest',
      'id' => 'I2-JH6TLLVWUK4CMUKAUUT553H2Q57RUKLX5DBEBNMIUVS3RNOT3LRA0000',
      'status' => 'active',
      'intent' => 'order',
      'category' => [
        { 'coding' => [
          { 'system' => 'http://terminology.hl7.org/CodeSystem/medicationrequest-category',
            'code' => 'outpatient',
            'display' => 'Outpatient' }
        ],
          'text' => 'Outpatient' }
      ],
      'medicationReference' => {
        'reference' => 'https://sandbox-api.va.gov/services/fhir/v0/r4/Medication/I2-D4UEEE77GHB7YU67LTAK6URFCD7NFTWEFMA6RCCVITIPG6NLXT3Q0000',
        'display' => 'Escitalopram 10 MG'
      }, 'subject' => {
        'reference' => 'https://sandbox-api.va.gov/services/fhir/v0/r4/Patient/1012667169V030190',
        'display' => 'Mr. Jesse Gray'
      }, 'authoredOn' => '2018-02-03T08:00:00Z',
      'requester' => {
        'reference' => 'https://sandbox-api.va.gov/services/fhir/v0/r4/Practitioner/I2-HRJI2MVST2IQSPR7U5SACWIWZA000000',
        'display' => 'DR. JANE460 DOE922 MD'
      }, 'dosageInstruction' => [{
        'timing' => {
          'repeat' => {
            'boundsPeriod' => {
              'start' => '2018-02-03T08:00:00Z'
            }
          }, 'code' => {
            'text' => 'Once Per Day'
          }
        },
        'asNeededBoolean' => false, 'route' => {
          'text' => 'ORAL'
        }, 'doseAndRate' => [
          { 'doseQuantity' => { 'value' => 1.0 } }
        ]
      }],
      'dispenseRequest' => {
        'numberOfRepeatsAllowed' => 0, 'quantity' => {
          'value' => 1.0
        }, 'expectedSupplyDuration' => {
          'value' => 30,
          'unit' => 'days',
          'system' => 'http://unitsofmeasure.org',
          'code' => 'd'
        }
      }
    },
    'search' => {
      'mode' => 'match'
    }
  }, {
    'fullUrl' => 'https://sandbox-api.va.gov/services/fhir/v0/r4/MedicationRequest/I2-JH6TLLVWUK4CMUKAUUT553H2Q626H2G63YS4FJRMG4WECODPCRKA0000',
    'resource' => {
      'resourceType' => 'MedicationRequest',
      'id' => 'I2-JH6TLLVWUK4CMUKAUUT553H2Q626H2G63YS4FJRMG4WECODPCRKA0000',
      'status' => 'active',
      'intent' => 'order',
      'category' => [{
        'coding' => [{
          'system' => 'http://terminology.hl7.org/CodeSystem/medicationrequest-category',
          'code' => 'outpatient',
          'display' => 'Outpatient'
        }],
        'text' => 'Outpatient'
      }],
      'medicationReference' => {
        'reference' => 'https://sandbox-api.va.gov/services/fhir/v0/r4/Medication/I2-D4UEEE77GHB7YU67LTAK6URFCC26ILINKE53FR5L7CBWOFR6APOA0000',
        'display' => 'Omeprazole 10 MG'
      },
      'subject' => {
        'reference' => 'https://sandbox-api.va.gov/services/fhir/v0/r4/Patient/1012667169V030190',
        'display' => 'Mr. Jesse Gray'
      },
      'authoredOn' => '2021-04-15T08:00:00Z',
      'requester' => {
        'reference' => 'https://sandbox-api.va.gov/services/fhir/v0/r4/Practitioner/I2-HRJI2MVST2IQSPR7U5SACWIWZA000000',
        'display' => 'DR. JANE460 DOE922 MD'
      },
      'dosageInstruction' => [{
        'text' => 'As directed by physician',
        'asNeededBoolean' => false,
        'route' => {
          'text' => 'ORAL'
        },
        'doseAndRate' => [{ 'doseQuantity' => { 'value' => 1.0 } }]
      }],
      'dispenseRequest' => {
        'numberOfRepeatsAllowed' => 0, 'quantity' => {
          'value' => 1.0
        },
        'expectedSupplyDuration' => {
          'value' => 30,
          'unit' => 'days',
          'system' => 'http://unitsofmeasure.org',
          'code' => 'd'
        }
      }
    },
    'search' => {
      'mode' => 'match'
    }
  }]
}

RSpec.describe FastTrack::HypertensionMedicationRequestData, :vcr do
  subject { described_class }

  let(:response) do
    # Using specific test ICN below:
    client = Lighthouse::VeteransHealth::Client.new(2_000_163)
    client.get_resource('medications')
  end

  describe '#transform' do
    empty_response = OpenStruct.new
    empty_response.body = { 'entry' => [] }
    it 'returns the expected hash from an empty list' do
      expect(described_class.new(empty_response).transform)
        .to eq([])
    end

    context 'testing inconsistent dosage instructions' do
      response = OpenStruct.new
      response.body = medication_response

      it 'is still successful if keys are empty' do
        expect { described_class.new(response).transform }.not_to raise_error
      end
    end

    it 'returns the expected hash from a single-entry list' do
      expect(described_class.new(response).transform).to match(
        [
          {
            'status' => 'active',
            'authoredOn' => '1995-02-06T02:15:52Z',
            'description' => 'Hydrochlorothiazide 6.25 MG',
            'notes' => ['Hydrochlorothiazide 6.25 MG'],
            'dosageInstructions' => ['Once per day.', 'As directed by physician.']
          },
          { 'status' => 'active',
            'authoredOn' => '1995-04-30T01:15:52Z',
            'description' => 'Loratadine 5 MG Chewable Tablet',
            'notes' => ['Loratadine 5 MG Chewable Tablet'],
            'dosageInstructions' => ['Once per day.', 'As directed by physician.'] },
          { 'status' => 'active',
            'authoredOn' => '1995-04-30T01:15:52Z',
            'description' => '0.3 ML EPINEPHrine 0.5 MG/ML Auto-Injector',
            'notes' => [
              '0.3 ML EPINEPHrine 0.5 MG/ML Auto-Injector'
            ],
            'dosageInstructions' => ['Once per day.', 'As directed by physician.'] },
          { 'status' => 'active',
            'authoredOn' => '1998-02-12T02:15:52Z',
            'description' => '120 ACTUAT Fluticasone propionate 0.044 MG/ACTUAT Metered Dose Inhaler',
            'notes' => [
              '120 ACTUAT Fluticasone propionate 0.044 MG/ACTUAT Metered Dose Inhaler'
            ],
            'dosageInstructions' => ['Once per day.', 'As directed by physician.'] },
          { 'status' => 'active',
            'authoredOn' => '1998-02-12T02:15:52Z',
            'description' => '200 ACTUAT Albuterol 0.09 MG/ACTUAT Metered Dose Inhaler',
            'notes' => ['200 ACTUAT Albuterol 0.09 MG/ACTUAT Metered Dose Inhaler'],
            'dosageInstructions' => ['Once per day.', 'As directed by physician.'] },
          { 'status' => 'active',
            'authoredOn' => '2009-03-25T01:15:52Z',
            'description' => 'Hydrocortisone 10 MG/ML ' \
                             'Topical Cream',
            'notes' => ['Hydrocortisone 10 MG/ML Topical Cream'],
            'dosageInstructions' => ['Once per day.', 'As directed by physician.'] },
          { 'status' => 'active',
            'authoredOn' => '2012-08-18T06:15:52Z',
            'description' => 'predniSONE 5 MG Oral Tablet',
            'notes' => ['predniSONE 5 MG Oral Tablet'],
            'dosageInstructions' => [
              '1 dose(s) 1 time(s) per 1 days', 'As directed by physician.'
            ] },
          { 'status' => 'active',
            'authoredOn' => '2013-04-15T01:15:52Z',
            'description' => 'Hydrochlorothiazide 25 MG',
            'notes' => ['Hydrochlorothiazide 25 MG'],
            'dosageInstructions' => ['Once per day.', 'As directed by physician.'] }
        ].sort_by { |med| med['authoredOn'].to_date }.reverse!
      )
    end
  end
end
