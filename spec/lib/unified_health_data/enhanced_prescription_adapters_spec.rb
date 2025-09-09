# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/models/prescription_attributes'
require 'unified_health_data/models/prescription'
require 'unified_health_data/adapters/vista_prescription_adapter'
require 'unified_health_data/adapters/oracle_health_prescription_adapter'

describe 'Enhanced UHD Prescription Adapters' do
  describe UnifiedHealthData::Adapters::VistaPrescriptionAdapter do
    subject { described_class.new }

    let(:vista_medication_with_tracking) do
      {
        'prescriptionId' => '28148665',
        'refillStatus' => 'active',
        'refillDate' => '2025-07-14',
        'refillRemaining' => 11,
        'facilityName' => 'SLC4',
        'isRefillable' => true,
        'isTrackable' => true,
        'sig' => 'Take one daily',
        'prescriptionName' => 'Test Medication',
        'trackingNumber' => 'TRACK123456789',
        'shipper' => 'UPS',
        'ndcNumber' => '12345-678-90',
        'prescribedDate' => '2025-07-01',
        'dataSourceSystem' => 'VISTA'
      }
    end

    let(:vista_medication_with_multiple_tracking) do
      {
        'prescriptionId' => '28148666',
        'refillStatus' => 'active',
        'prescriptionName' => 'Test Medication 2',
        'trackingInfo' => [
          { 'trackingNumber' => 'TRACK111', 'shipper' => 'UPS' },
          { 'trackingNumber' => 'TRACK222', 'shipper' => 'FedEx' }
        ]
      }
    end

    describe '#parse' do
      context 'with single tracking info' do
        let(:prescription) { subject.parse(vista_medication_with_tracking) }

        it 'creates prescription with tracking info array' do
          expect(prescription).to be_a(UnifiedHealthData::Prescription)
          expect(prescription.tracking_info).to be_an(Array)
          expect(prescription.tracking_info.size).to eq(1)
          expect(prescription.tracking_info.first).to eq({
            'tracking_number' => 'TRACK123456789',
            'shipper' => 'UPS'
          })
        end

        it 'provides mobile v1 compatibility methods' do
          expect(prescription.tracking_number).to eq('TRACK123456789')
          expect(prescription.shipper).to eq('UPS')
          expect(prescription.prescription_source).to eq('VISTA')
          expect(prescription.ndc_number).to eq('12345-678-90')
          expect(prescription.prescribed_date).to eq('2025-07-01')
        end

        it 'includes data_source_system' do
          expect(prescription.data_source_system).to eq('VISTA')
        end
      end

      context 'with multiple tracking info' do
        let(:prescription) { subject.parse(vista_medication_with_multiple_tracking) }

        it 'creates prescription with multiple tracking entries' do
          expect(prescription.tracking_info.size).to eq(2)
          expect(prescription.tracking_info[0]).to eq({
            'tracking_number' => 'TRACK111',
            'shipper' => 'UPS'
          })
          expect(prescription.tracking_info[1]).to eq({
            'tracking_number' => 'TRACK222',
            'shipper' => 'FedEx'
          })
        end

        it 'provides first tracking info for compatibility' do
          expect(prescription.tracking_number).to eq('TRACK111')
          expect(prescription.shipper).to eq('UPS')
        end
      end

      context 'with no tracking info' do
        let(:vista_medication_no_tracking) do
          { 'prescriptionId' => '123', 'prescriptionName' => 'Test' }
        end
        let(:prescription) { subject.parse(vista_medication_no_tracking) }

        it 'returns empty tracking info array' do
          expect(prescription.tracking_info).to eq([])
          expect(prescription.tracking_number).to be_nil
          expect(prescription.shipper).to be_nil
        end
      end
    end
  end

  describe UnifiedHealthData::Adapters::OracleHealthPrescriptionAdapter do
    subject { described_class.new }

    let(:oracle_medication_with_tracking) do
      {
        'resourceType' => 'MedicationRequest',
        'id' => '15208365735',
        'status' => 'active',
        'authoredOn' => '2025-01-29T19:41:43Z',
        'medicationCodeableConcept' => {
          'text' => 'Test Medication',
          'coding' => [
            {
              'system' => 'http://hl7.org/fhir/sid/ndc',
              'code' => '12345-678-90'
            }
          ]
        },
        'extension' => [
          {
            'url' => 'http://example.com/tracking',
            'valueString' => 'TRACK987654321'
          }
        ],
        'contained' => [
          {
            'resourceType' => 'MedicationDispense',
            'id' => 'dispense1',
            'identifier' => [
              {
                'type' => { 'text' => 'tracking number' },
                'value' => 'FEDEX123456789',
                'assigner' => { 'display' => 'FedEx' }
              }
            ]
          }
        ]
      }
    end

    describe '#parse' do
      context 'with tracking information' do
        let(:prescription) { subject.parse(oracle_medication_with_tracking) }

        it 'creates prescription with extracted tracking info' do
          expect(prescription).to be_a(UnifiedHealthData::Prescription)
          expect(prescription.tracking_info).to be_an(Array)
          expect(prescription.tracking_info).not_to be_empty
        end

        it 'extracts NDC number' do
          expect(prescription.ndc_number).to eq('12345-678-90')
        end

        it 'sets correct prescription source' do
          expect(prescription.prescription_source).to eq('UHD')
          expect(prescription.data_source_system).to eq('ORACLE_HEALTH')
        end

        it 'determines trackability based on tracking info' do
          expect(prescription.trackable?).to be(true)
        end

        it 'sets prescribed date from authoredOn' do
          expect(prescription.prescribed_date).to eq('2025-01-29T19:41:43Z')
        end
      end

      context 'without tracking information' do
        let(:oracle_medication_no_tracking) do
          {
            'resourceType' => 'MedicationRequest',
            'id' => '123',
            'status' => 'active',
            'medicationCodeableConcept' => { 'text' => 'Test Med' }
          }
        end
        let(:prescription) { subject.parse(oracle_medication_no_tracking) }

        it 'returns empty tracking info' do
          expect(prescription.tracking_info).to eq([])
          expect(prescription.trackable?).to be(false)
        end
      end
    end
  end

  describe 'Mobile V1 Compatibility' do
    let(:vista_adapter) { UnifiedHealthData::Adapters::VistaPrescriptionAdapter.new }
    let(:vista_prescription) { vista_adapter.parse(vista_medication_data) }

    let(:vista_medication_data) do
      {
        'prescriptionId' => '123',
        'prescriptionName' => 'Test Med',
        'trackingNumber' => 'TRACK123',
        'shipper' => 'UPS'
      }
    end

    it 'provides all mobile v0 compatible methods' do
      expect(vista_prescription).to respond_to(:prescription_id)
      expect(vista_prescription).to respond_to(:refill_status)
      expect(vista_prescription).to respond_to(:refill_date)
      expect(vista_prescription).to respond_to(:refillable?)
      expect(vista_prescription).to respond_to(:trackable?)
      expect(vista_prescription).to respond_to(:sig)
      expect(vista_prescription).to respond_to(:cmop_division_phone)
    end

    it 'provides mobile v1 specific methods' do
      expect(vista_prescription).to respond_to(:tracking_info)
      expect(vista_prescription).to respond_to(:tracking_number)
      expect(vista_prescription).to respond_to(:shipper)
      expect(vista_prescription).to respond_to(:prescription_source)
      expect(vista_prescription).to respond_to(:data_source_system)
      expect(vista_prescription).to respond_to(:ndc_number)
      expect(vista_prescription).to respond_to(:prescribed_date)
    end

    it 'maintains backward compatibility for tracking fields' do
      expect(vista_prescription.tracking_number).to eq('TRACK123')
      expect(vista_prescription.shipper).to eq('UPS')
      expect(vista_prescription.tracking_info).to eq([{
        'tracking_number' => 'TRACK123',
        'shipper' => 'UPS'
      }])
    end
  end
end
