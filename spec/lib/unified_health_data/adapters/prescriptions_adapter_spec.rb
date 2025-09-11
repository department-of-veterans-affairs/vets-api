# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/models/prescription_attributes'
require 'unified_health_data/models/prescription'
require 'unified_health_data/adapters/prescriptions_adapter'

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
  end
end
