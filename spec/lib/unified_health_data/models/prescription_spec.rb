# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/models/prescription_attributes'
require 'unified_health_data/models/prescription'

describe UnifiedHealthData::Prescription do
  let(:prescription_attributes) do
    UnifiedHealthData::PrescriptionAttributes.new(
      prescription_name: 'Test Medication',
      refill_status: 'active',
      is_refillable: true,
      is_trackable: true,
      instructions: 'Take once daily',
      facility_phone_number: '555-1234',
      data_source_system: 'VISTA',
      prescription_source: 'VISTA',
      ndc_number: '12345-678-90',
      prescribed_date: '2025-07-01',
      tracking_info: [
        { 'tracking_number' => 'TRACK123', 'shipper' => 'UPS' },
        { 'tracking_number' => 'TRACK456', 'shipper' => 'FedEx' }
      ]
    )
  end

  let(:prescription) do
    described_class.new(
      id: '123',
      type: 'Prescription',
      attributes: prescription_attributes
    )
  end

  describe 'mobile v0 compatibility methods' do
    it 'delegates to attributes' do
      expect(prescription.prescription_id).to eq('123')
      expect(prescription.prescription_name).to eq('Test Medication')
      expect(prescription.refill_status).to eq('active')
      expect(prescription.refillable?).to be(true)
      expect(prescription.trackable?).to be(true)
      expect(prescription.sig).to eq('Take once daily')
      expect(prescription.cmop_division_phone).to eq('555-1234')
    end
  end

  describe 'mobile v1 specific methods' do
    it 'provides tracking info array' do
      expect(prescription.tracking_info).to be_an(Array)
      expect(prescription.tracking_info.size).to eq(2)
      expect(prescription.tracking_info[0]).to eq({
        'tracking_number' => 'TRACK123',
        'shipper' => 'UPS'
      })
    end

    it 'provides first tracking number for backward compatibility' do
      expect(prescription.tracking_number).to eq('TRACK123')
      expect(prescription.shipper).to eq('UPS')
    end

    it 'provides UHD-specific fields' do
      expect(prescription.prescription_source).to eq('VISTA')
      expect(prescription.data_source_system).to eq('VISTA')
      expect(prescription.ndc_number).to eq('12345-678-90')
      expect(prescription.prescribed_date).to eq('2025-07-01')
    end
  end

  describe 'when tracking_info is empty' do
    let(:prescription_attributes_no_tracking) do
      UnifiedHealthData::PrescriptionAttributes.new(
        prescription_name: 'Test Medication',
        tracking_info: []
      )
    end

    let(:prescription_no_tracking) do
      described_class.new(
        id: '123',
        attributes: prescription_attributes_no_tracking
      )
    end

    it 'returns nil for tracking number and shipper' do
      expect(prescription_no_tracking.tracking_number).to be_nil
      expect(prescription_no_tracking.shipper).to be_nil
      expect(prescription_no_tracking.tracking_info).to eq([])
    end
  end

  describe 'when tracking_info has symbol keys' do
    let(:prescription_attributes_symbol_keys) do
      UnifiedHealthData::PrescriptionAttributes.new(
        tracking_info: [
          { tracking_number: 'TRACK789', shipper: 'USPS' }
        ]
      )
    end

    let(:prescription_symbol_keys) do
      described_class.new(
        id: '123',
        attributes: prescription_attributes_symbol_keys
      )
    end

    it 'handles symbol keys correctly' do
      expect(prescription_symbol_keys.tracking_number).to eq('TRACK789')
      expect(prescription_symbol_keys.shipper).to eq('USPS')
    end
  end
end
