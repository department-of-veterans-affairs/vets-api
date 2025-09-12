# frozen_string_literal: true

# Spec for UnifiedHealthData::Adapters::PrescriptionsAdapter
require 'rails_helper'
require 'unified_health_data/models/prescription_attributes'
require 'unified_health_data/models/prescription'
require 'unified_health_data/adapters/prescriptions_adapter'
require 'unified_health_data/adapters/oracle_health_prescription_adapter'

describe UnifiedHealthData::Adapters::PrescriptionsAdapter do
  subject { described_class.new }

  let(:vista_medication_data) do
    {
      'prescriptionId' => '28148665',
      'refillStatus' => 'active',
      'refillSubmitDate' => nil,
      'refillDate' => 'Mon, 14 Jul 2025 00:00:00 EDT',
      'refillRemaining' => 11,
      'facilityName' => 'SLC4',
      'isRefillable' => true,
      'isTrackable' => false,
      'sig' => 'APPLY TEASPOONFUL(S) TO THE AFFECTED AREA EVERY DAY',
      'orderedDate' => 'Mon, 14 Jul 2025 00:00:00 EDT',
      'quantity' => 1,
      'expirationDate' => 'Wed, 15 Jul 2026 00:00:00 EDT',
      'prescriptionNumber' => '3636485',
      'prescriptionName' => 'COAL TAR 2.5% TOP SOLN',
      'dispensedDate' => nil,
      'stationNumber' => '991',
      'cmopDivisionPhone' => '555-1234',
      'dataSourceSystem' => 'VISTA'
    }
  end

  let(:oracle_health_medication_data) do
    {
      'resourceType' => 'MedicationRequest',
      'id' => '15208365735',
      'status' => 'active',
      'authoredOn' => '2025-01-29T19:41:43Z',
      'medicationCodeableConcept' => {
        'text' => 'amLODIPine (amLODIPine 5 mg tablet)'
      },
      'dosageInstruction' => [
        {
          'text' => 'See Instructions, daily, 1 EA, 0 Refill(s)'
        }
      ],
      'dispenseRequest' => {
        'numberOfRepeatsAllowed' => 0,
        'quantity' => {
          'value' => 1,
          'unit' => 'EA'
        }
      },
      'contained' => [
        {
          'resourceType' => 'MedicationDispense',
          'id' => 'dispense-1',
          'whenHandedOver' => '2025-01-15T10:00:00Z',
          'quantity' => { 'value' => 30 },
          'location' => { 'display' => 'Main Pharmacy' }
        },
        {
          'resourceType' => 'MedicationDispense',
          'id' => 'dispense-2',
          'whenHandedOver' => '2025-01-29T14:30:00Z',
          'quantity' => { 'value' => 30 },
          'location' => { 'display' => 'Main Pharmacy' }
        },
        {
          'resourceType' => 'MedicationDispense',
          'id' => 'dispense-3',
          'whenHandedOver' => '2025-01-22T09:15:00Z',
          'quantity' => { 'value' => 30 },
          'location' => { 'display' => 'Main Pharmacy' }
        }
      ]
    }
  end

  let(:unified_response) do
    {
      'vista' => {
        'medicationList' => {
          'medication' => [vista_medication_data]
        }
      },
      'oracle-health' => {
        'entry' => [
          {
            'resource' => oracle_health_medication_data
          }
        ]
      }
    }
  end

  describe '#parse' do
    context 'with unified response data' do
      it 'returns prescriptions from both VistA and Oracle Health' do
        prescriptions = subject.parse(unified_response)

        expect(prescriptions.size).to eq(2)
        expect(prescriptions).to all(be_a(UnifiedHealthData::Prescription))

        vista_prescription = prescriptions.find { |p| p.prescription_id == '28148665' }
        oracle_prescription = prescriptions.find { |p| p.prescription_id == '15208365735' }

        expect(vista_prescription).to be_present
        expect(oracle_prescription).to be_present
      end
    end

    context 'with VistA-only data' do
      let(:vista_only_response) do
        {
          'vista' => unified_response['vista'],
          'oracle-health' => nil
        }
      end

      it 'returns only VistA prescriptions' do
        prescriptions = subject.parse(vista_only_response)

        expect(prescriptions.size).to eq(1)
        expect(prescriptions.first.prescription_id).to eq('28148665')
        expect(prescriptions.first.prescription_name).to eq('COAL TAR 2.5% TOP SOLN')
      end
    end

    context 'with Oracle Health-only data' do
      let(:oracle_only_response) do
        {
          'vista' => nil,
          'oracle-health' => unified_response['oracle-health']
        }
      end

      it 'returns only Oracle Health prescriptions' do
        prescriptions = subject.parse(oracle_only_response)

        expect(prescriptions.size).to eq(1)
        expect(prescriptions.first.prescription_id).to eq('15208365735')
        expect(prescriptions.first.prescription_name).to eq('amLODIPine (amLODIPine 5 mg tablet)')
      end
    end

    context 'with nil input' do
      it 'returns empty array' do
        expect(subject.parse(nil)).to eq([])
      end
    end

    context 'with empty data' do
      let(:empty_response) do
        {
          'vista' => { 'medicationList' => { 'medication' => [] } },
          'oracle-health' => { 'entry' => [] }
        }
      end

      it 'returns empty array' do
        expect(subject.parse(empty_response)).to eq([])
      end
    end

    context 'with Oracle Health data containing multiple MedicationDispense resources' do
      it 'uses the most recent dispensed date based on whenHandedOver' do
        prescriptions = subject.parse(unified_response)
        oracle_prescription = prescriptions.find { |p| p.prescription_id == '15208365735' }

        # Should use the most recent whenHandedOver date: '2025-01-29T14:30:00Z'
        expect(oracle_prescription.dispensed_date).to eq('2025-01-29T14:30:00Z')
      end
    end

    context 'with Oracle Health data containing encounter location' do
      let(:oracle_medication_with_encounter) do
        {
          'resourceType' => 'MedicationRequest',
          'id' => '15208365735',
          'status' => 'active',
          'authoredOn' => '2025-01-29T19:41:43Z',
          'medicationCodeableConcept' => {
            'text' => 'amLODIPine (amLODIPine 5 mg tablet)'
          },
          'contained' => [
            {
              'resourceType' => 'Encounter',
              'id' => 'encounter-1',
              'location' => [
                {
                  'location' => {
                    'display' => 'VA Medical Center - Cardiology'
                  }
                }
              ]
            }
          ]
        }
      end

      let(:response_with_encounter) do
        {
          'vista' => nil,
          'oracle-health' => {
            'entry' => [
              {
                'resource' => oracle_medication_with_encounter
              }
            ]
          }
        }
      end

      it 'extracts facility name from encounter location' do
        prescriptions = subject.parse(response_with_encounter)
        oracle_prescription = prescriptions.first

        expect(oracle_prescription.facility_name).to eq('VA Medical Center - Cardiology')
      end
    end
  end

  describe UnifiedHealthData::Adapters::OracleHealthPrescriptionAdapter do
    subject { described_class.new }

    let(:base_resource) do
      {
        'resourceType' => 'MedicationRequest',
        'id' => '12345',
        'status' => 'active',
        'authoredOn' => '2025-01-29T19:41:43Z',
        'medicationCodeableConcept' => {
          'text' => 'Test Medication'
        },
        'dosageInstruction' => [
          {
            'text' => 'Take as directed'
          }
        ]
      }
    end

    describe '#parse' do
      context 'with valid resource' do
        it 'returns a UnifiedHealthData::Prescription object' do
          result = subject.parse(base_resource)

          expect(result).to be_a(UnifiedHealthData::Prescription)
          expect(result.id).to eq('12345')
          expect(result.type).to eq('Prescription')
        end
      end

      context 'with nil resource' do
        it 'returns nil' do
          expect(subject.parse(nil)).to be_nil
        end
      end

      context 'with resource missing id' do
        let(:resource_without_id) { base_resource.except('id') }

        it 'returns nil' do
          expect(subject.parse(resource_without_id)).to be_nil
        end
      end

      context 'when parsing raises an error' do
        let(:adapter_with_error) do
          adapter = described_class.new
          allow(adapter).to receive(:build_prescription_attributes).and_raise(StandardError, 'Test error')
          adapter
        end

        before do
          allow(Rails.logger).to receive(:error)
        end

        it 'logs the error and returns nil' do
          result = adapter_with_error.parse(base_resource)

          expect(result).to be_nil
          expect(Rails.logger).to have_received(:error).with('Error parsing Oracle Health prescription: Test error')
        end
      end
    end

    describe '#extract_facility_name' do
      context 'with dispenseRequest performer' do
        let(:resource_with_performer) do
          base_resource.merge(
            'dispenseRequest' => {
              'performer' => {
                'display' => 'Main Pharmacy'
              }
            }
          )
        end

        it 'returns the performer display name' do
          result = subject.send(:extract_facility_name, resource_with_performer)
          expect(result).to eq('Main Pharmacy')
        end
      end

      context 'with encounter location in contained resources' do
        let(:resource_with_encounter) do
          base_resource.merge(
            'contained' => [
              {
                'resourceType' => 'Encounter',
                'id' => 'encounter-1',
                'location' => [
                  {
                    'location' => {
                      'display' => 'VA Medical Center - Emergency'
                    }
                  }
                ]
              }
            ]
          )
        end

        it 'returns the encounter location display name' do
          result = subject.send(:extract_facility_name, resource_with_encounter)
          expect(result).to eq('VA Medical Center - Emergency')
        end
      end

      context 'with multiple contained resources including encounter' do
        let(:resource_with_multiple_contained) do
          base_resource.merge(
            'contained' => [
              {
                'resourceType' => 'MedicationDispense',
                'id' => 'dispense-1'
              },
              {
                'resourceType' => 'Encounter',
                'id' => 'encounter-1',
                'location' => [
                  {
                    'location' => {
                      'display' => 'Outpatient Clinic'
                    }
                  }
                ]
              },
              {
                'resourceType' => 'Organization',
                'id' => 'org-1'
              }
            ]
          )
        end

        it 'finds and returns the encounter location display name' do
          result = subject.send(:extract_facility_name, resource_with_multiple_contained)
          expect(result).to eq('Outpatient Clinic')
        end
      end

      context 'with encounter but no location' do
        let(:resource_with_encounter_no_location) do
          base_resource.merge(
            'contained' => [
              {
                'resourceType' => 'Encounter',
                'id' => 'encounter-1'
              }
            ],
            'requester' => {
              'display' => 'Fallback Provider'
            }
          )
        end
      end

      context 'with no performer, encounter, or requester' do
        it 'returns nil' do
          result = subject.send(:extract_facility_name, base_resource)
          expect(result).to be_nil
        end
      end
    end

    describe '#extract_is_refillable' do
      context 'with active status and remaining refills' do
        let(:resource) do
          {
            'status' => 'active',
            'dispenseRequest' => {
              'numberOfRepeatsAllowed' => 5
            }
          }
        end

        it 'returns true' do
          expect(subject.send(:extract_is_refillable, resource)).to be true
        end
      end

      context 'with active status but no remaining refills' do
        let(:resource) do
          {
            'status' => 'active',
            'dispenseRequest' => {
              'numberOfRepeatsAllowed' => 0
            }
          }
        end

        it 'returns false' do
          expect(subject.send(:extract_is_refillable, resource)).to be false
        end
      end

      context 'with inactive status' do
        let(:resource) do
          {
            'status' => 'completed',
            'dispenseRequest' => {
              'numberOfRepeatsAllowed' => 5
            }
          }
        end

        it 'returns false' do
          expect(subject.send(:extract_is_refillable, resource)).to be false
        end
      end
    end
  end
end
