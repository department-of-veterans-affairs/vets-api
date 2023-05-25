# frozen_string_literal: true

require 'rails_helper'
require 'ostruct'
require 'lighthouse/veterans_health/client'

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

RSpec.describe RapidReadyForDecision::LighthouseMedicationRequestData do
  subject { described_class }

  around do |example|
    VCR.use_cassette('rrd/lighthouse_medication_requests', &example)
  end

  let(:response) do
    # Using specific test ICN that returns multiple pages below:
    client = Lighthouse::VeteransHealth::Client.new(32_000_225)
    client.list_medication_requests
  end
  let(:transformed_response) { described_class.new(response).transform }

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
      expect(transformed_response[0..19]).to match(
        [{ 'status' => 'active',
           'authoredOn' => '2006-04-17T02:42:52Z',
           'description' => 'PACLitaxel 100 MG Injection',
           'notes' => ['PACLitaxel 100 MG Injection'],
           'route' => 'As directed by physician.',
           'refills' => nil,
           'duration' => '',
           'dosageInstructions' => ['Once per day.', 'As directed by physician.'] },
         { 'status' => 'active',
           'authoredOn' => '2006-04-17T02:42:52Z',
           'description' => 'PACLitaxel 100 MG Injection',
           'notes' => ['PACLitaxel 100 MG Injection'],
           'route' => 'As directed by physician.',
           'refills' => nil,
           'duration' => '',
           'dosageInstructions' => ['Once per day.', 'As directed by physician.'] },
         { 'status' => 'active',
           'authoredOn' => '2006-04-17T02:42:52Z',
           'description' => 'Cisplatin 50 MG Injection',
           'notes' => ['Cisplatin 50 MG Injection'],
           'route' => 'As directed by physician.',
           'refills' => nil,
           'duration' => '',
           'dosageInstructions' => ['Once per day.', 'As directed by physician.'] },
         { 'status' => 'active',
           'authoredOn' => '2006-04-17T02:42:52Z',
           'description' => 'Cisplatin 50 MG Injection',
           'notes' => ['Cisplatin 50 MG Injection'],
           'route' => 'As directed by physician.',
           'refills' => nil,
           'duration' => '',
           'dosageInstructions' => ['Once per day.', 'As directed by physician.'] },
         { 'status' => 'active',
           'authoredOn' => '2006-03-16T03:42:52Z',
           'description' => 'PACLitaxel 100 MG Injection',
           'notes' => ['PACLitaxel 100 MG Injection'],
           'route' => 'As directed by physician.',
           'refills' => nil,
           'duration' => '',
           'dosageInstructions' => ['Once per day.', 'As directed by physician.'] },
         { 'status' => 'active',
           'authoredOn' => '2006-03-16T03:42:52Z',
           'description' => 'PACLitaxel 100 MG Injection',
           'notes' => ['PACLitaxel 100 MG Injection'],
           'route' => 'As directed by physician.',
           'refills' => nil,
           'duration' => '',
           'dosageInstructions' => ['Once per day.', 'As directed by physician.'] },
         { 'status' => 'active',
           'authoredOn' => '2006-03-16T03:42:52Z',
           'description' => 'Cisplatin 50 MG Injection',
           'notes' => ['Cisplatin 50 MG Injection'],
           'route' => 'As directed by physician.',
           'refills' => nil,
           'duration' => '',
           'dosageInstructions' => ['Once per day.', 'As directed by physician.'] },
         { 'status' => 'active',
           'authoredOn' => '2006-03-16T03:42:52Z',
           'description' => 'Cisplatin 50 MG Injection',
           'notes' => ['Cisplatin 50 MG Injection'],
           'route' => 'As directed by physician.',
           'refills' => nil,
           'duration' => '',
           'dosageInstructions' => ['Once per day.', 'As directed by physician.'] },
         { 'status' => 'active',
           'authoredOn' => '2006-02-11T03:42:52Z',
           'description' => 'Simvistatin 10 MG',
           'notes' => [],
           'route' => '',
           'refills' => 12,
           'duration' => '30 days',
           'dosageInstructions' => [] },
         { 'status' => 'active',
           'authoredOn' => '2006-02-10T03:42:52Z',
           'description' => 'PACLitaxel 100 MG Injection',
           'notes' => ['PACLitaxel 100 MG Injection'],
           'route' => 'As directed by physician.',
           'refills' => nil,
           'duration' => '',
           'dosageInstructions' => ['Once per day.', 'As directed by physician.'] },
         { 'status' => 'active',
           'authoredOn' => '2006-02-10T03:42:52Z',
           'description' => 'PACLitaxel 100 MG Injection',
           'notes' => ['PACLitaxel 100 MG Injection'],
           'route' => 'As directed by physician.',
           'refills' => nil,
           'duration' => '',
           'dosageInstructions' => ['Once per day.', 'As directed by physician.'] },
         { 'status' => 'active',
           'authoredOn' => '2006-02-10T03:42:52Z',
           'description' => 'Cisplatin 50 MG Injection',
           'notes' => ['Cisplatin 50 MG Injection'],
           'route' => 'As directed by physician.',
           'refills' => nil,
           'duration' => '',
           'dosageInstructions' => ['Once per day.', 'As directed by physician.'] },
         { 'status' => 'active',
           'authoredOn' => '2006-02-10T03:42:52Z',
           'description' => 'Cisplatin 50 MG Injection',
           'notes' => ['Cisplatin 50 MG Injection'],
           'route' => 'As directed by physician.',
           'refills' => nil,
           'duration' => '',
           'dosageInstructions' => ['Once per day.', 'As directed by physician.'] },
         { 'status' => 'active',
           'authoredOn' => '2006-01-12T03:42:52Z',
           'description' => 'Simvistatin 10 MG',
           'notes' => ['Simvistatin 10 MG'],
           'route' => 'As directed by physician.',
           'refills' => nil,
           'duration' => '',
           'dosageInstructions' =>
           ['1 dose(s) 1 time(s) per 1 days', 'As directed by physician.'] },
         { 'status' => 'active',
           'authoredOn' => '2006-01-12T03:42:52Z',
           'description' => 'Simvistatin 10 MG',
           'notes' => ['Simvistatin 10 MG'],
           'route' => 'As directed by physician.',
           'refills' => nil,
           'duration' => '',
           'dosageInstructions' =>
           ['1 dose(s) 1 time(s) per 1 days', 'As directed by physician.'] },
         { 'status' => 'active',
           'authoredOn' => '2006-01-12T03:42:52Z',
           'description' => 'PACLitaxel 100 MG Injection',
           'notes' => ['PACLitaxel 100 MG Injection'],
           'route' => 'As directed by physician.',
           'refills' => nil,
           'duration' => '',
           'dosageInstructions' => ['Once per day.', 'As directed by physician.'] },
         { 'status' => 'active',
           'authoredOn' => '2006-01-12T03:42:52Z',
           'description' => 'PACLitaxel 100 MG Injection',
           'notes' => ['PACLitaxel 100 MG Injection'],
           'route' => 'As directed by physician.',
           'refills' => nil,
           'duration' => '',
           'dosageInstructions' => ['Once per day.', 'As directed by physician.'] },
         { 'status' => 'active',
           'authoredOn' => '2006-01-12T03:42:52Z',
           'description' => 'Cisplatin 50 MG Injection',
           'notes' => ['Cisplatin 50 MG Injection'],
           'route' => 'As directed by physician.',
           'refills' => nil,
           'duration' => '',
           'dosageInstructions' => ['Once per day.', 'As directed by physician.'] },
         { 'status' => 'active',
           'authoredOn' => '2006-01-12T03:42:52Z',
           'description' => 'Cisplatin 50 MG Injection',
           'notes' => ['Cisplatin 50 MG Injection'],
           'route' => 'As directed by physician.',
           'refills' => nil,
           'duration' => '',
           'dosageInstructions' => ['Once per day.', 'As directed by physician.'] },
         { 'status' => 'active',
           'authoredOn' => '2005-12-11T03:42:52Z',
           'description' => 'PACLitaxel 100 MG Injection',
           'notes' => ['PACLitaxel 100 MG Injection'],
           'route' => 'As directed by physician.',
           'refills' => nil,
           'duration' => '',
           'dosageInstructions' => ['Once per day.', 'As directed by physician.'] }]
      )
    end

    it 'returns all of the medications that are active' do
      only_active_meds = response.body['entry'].select { |med| med.dig('resource', 'status') == 'active' }
      expect(transformed_response.count).to match only_active_meds.count
    end
  end
end
