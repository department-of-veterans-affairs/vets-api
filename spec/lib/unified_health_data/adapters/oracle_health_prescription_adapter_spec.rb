# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/models/prescription'
require 'unified_health_data/adapters/oracle_health_prescription_adapter'
require 'lighthouse/facilities/v1/client'
require 'lighthouse/facilities/v1/client'

RSpec.describe UnifiedHealthData::Adapters::OracleHealthPrescriptionAdapter do
  subject(:adapter) { described_class.new }

  let(:valid_resource) do
    {
      'id' => 'test-prescription-123',
      'status' => 'active',
      'medicationCodeableConcept' => { 'text' => 'Test Medication' },
      'authoredOn' => '2023-01-15T10:00:00Z',
      'contained' => [
        {
          'resourceType' => 'MedicationDispense',
          'status' => 'completed',
          'whenHandedOver' => '2023-01-20T14:30:00Z',
          'location' => { 'display' => '648-PHARMACY-MAIN' },
          'quantity' => { 'value' => 30 }
        }
      ]
    }
  end

  describe '#parse' do
    context 'with valid resource' do
      it 'returns a UnifiedHealthData::Prescription object' do
        result = adapter.parse(valid_resource)
        
        expect(result).to be_a(UnifiedHealthData::Prescription)
        expect(result.id).to eq('test-prescription-123')
        expect(result.type).to eq('Prescription')
      end
    end

    context 'with nil resource' do
      it 'returns nil' do
        expect(adapter.parse(nil)).to be_nil
      end
    end

    context 'with resource missing id' do
      it 'returns nil' do
        invalid_resource = valid_resource.dup
        invalid_resource.delete('id')
        
        expect(adapter.parse(invalid_resource)).to be_nil
      end
    end

    context 'when an error occurs during parsing' do
      before do
        allow(adapter).to receive(:build_prescription_attributes).and_raise(StandardError, 'Test error')
        allow(Rails.logger).to receive(:error)
      end

      it 'logs the error and returns nil' do
        result = adapter.parse(valid_resource)
        
        expect(result).to be_nil
        expect(Rails.logger).to have_received(:error).with('Error parsing Oracle Health prescription: Test error')
      end
    end
  end

  describe '#extract_facility_name' do
    let(:resource_with_dispense) do
      {
        'contained' => [
          {
            'resourceType' => 'MedicationDispense',
            'status' => 'completed',
            'whenHandedOver' => '2023-01-20T14:30:00Z',
            'location' => { 'display' => '648-PHARMACY-MAIN' }
          }
        ]
      }
    end

    let(:resource_with_multiple_dispenses) do
      {
        'contained' => [
          {
            'resourceType' => 'MedicationDispense',
            'status' => 'completed',
            'whenHandedOver' => '2023-01-15T10:00:00Z',
            'location' => { 'display' => '556-PHARMACY-OLD' }
          },
          {
            'resourceType' => 'MedicationDispense',
            'status' => 'completed',
            'whenHandedOver' => '2023-01-20T14:30:00Z',
            'location' => { 'display' => '648-PHARMACY-MAIN' }
          }
        ]
      }
    end

    let(:resource_without_dispense) do
      { 'contained' => [] }
    end

    let(:resource_without_location) do
      {
        'contained' => [
          {
            'resourceType' => 'MedicationDispense',
            'status' => 'completed',
            'whenHandedOver' => '2023-01-20T14:30:00Z'
          }
        ]
      }
    end

    let(:resource_with_invalid_station) do
      {
        'contained' => [
          {
            'resourceType' => 'MedicationDispense',
            'status' => 'completed',
            'whenHandedOver' => '2023-01-20T14:30:00Z',
            'location' => { 'display' => 'INVALID-STATION-FORMAT' }
          }
        ]
      }
    end

    before do
      # Mock Rails cache
      allow(Rails.cache).to receive(:read).and_return(nil)
      allow(Rails.cache).to receive(:write)
      # Mock StatsD
      allow(StatsD).to receive(:increment)
    end

    context 'when Rails cache has the facility name' do
      before do
        allow(Rails.cache).to receive(:read).with('uhd:facility_names:648').and_return('Portland VA Medical Center')
      end

      it 'returns the cached facility name' do
        result = adapter.send(:extract_facility_name, resource_with_dispense)
        
        expect(result).to eq('Portland VA Medical Center')
        expect(Rails.cache).to have_received(:read).with('uhd:facility_names:648')
        expect(StatsD).to have_received(:increment).with('unified_health_data.facility_name_cache.hit')
      end
    end

    context 'when Rails cache fails due to connection error' do
      let(:mock_lighthouse_client) { instance_double(Lighthouse::Facilities::V1::Client) }
      let(:mock_facility) { double('Facility', name: 'Portland VA Medical Center') }

      before do
        allow(Rails.cache).to receive(:read).and_raise(StandardError, 'Connection failed')
        allow(Rails.cache).to receive(:write)
        allow(Lighthouse::Facilities::V1::Client).to receive(:new).and_return(mock_lighthouse_client)
        allow(mock_lighthouse_client).to receive(:get_facilities).with(facilityIds: 'vha_648').and_return([mock_facility])
        allow(Rails.logger).to receive(:warn)
        allow(Rails.logger).to receive(:info)
      end

      it 'logs the error and falls back to API call' do
        result = adapter.send(:extract_facility_name, resource_with_dispense)
        
        expect(result).to eq('Portland VA Medical Center')
        expect(Rails.logger).to have_received(:warn).with(/Rails cache lookup failed for facility 648/)
        expect(StatsD).to have_received(:increment).with('unified_health_data.facility_name_cache.error')
        expect(StatsD).to have_received(:increment).with('unified_health_data.facility_name_fallback.api_hit')
        expect(mock_lighthouse_client).to have_received(:get_facilities).with(facilityIds: 'vha_648')
      end
    end

    context 'when Rails cache is empty but API has the facility' do
      let(:mock_lighthouse_client) { instance_double(Lighthouse::Facilities::V1::Client) }
      let(:mock_facility) { double('Facility', name: 'Portland VA Medical Center') }

      before do
        allow(Rails.cache).to receive(:read).with('uhd:facility_names:648').and_return(nil)
        allow(Rails.cache).to receive(:write)
        allow(Lighthouse::Facilities::V1::Client).to receive(:new).and_return(mock_lighthouse_client)
        allow(mock_lighthouse_client).to receive(:get_facilities).with(facilityIds: 'vha_648').and_return([mock_facility])
        allow(Rails.logger).to receive(:info)
      end

      it 'returns the facility name from API and caches it' do
        result = adapter.send(:extract_facility_name, resource_with_dispense)
        
        expect(result).to eq('Portland VA Medical Center')
        expect(Rails.cache).to have_received(:read).with('uhd:facility_names:648')
        expect(mock_lighthouse_client).to have_received(:get_facilities).with(facilityIds: 'vha_648')
        expect(Rails.cache).to have_received(:write).with('uhd:facility_names:648', 'Portland VA Medical Center', expires_in: 4.hours)
        expect(StatsD).to have_received(:increment).with('unified_health_data.facility_name_cache.miss')
        expect(StatsD).to have_received(:increment).with('unified_health_data.facility_name_fallback.api_hit')
      end
    end

    context 'when neither cache nor API has the facility' do
      let(:mock_lighthouse_client) { instance_double(Lighthouse::Facilities::V1::Client) }

      before do
        allow(Rails.cache).to receive(:read).with('uhd:facility_names:648').and_return(nil)
        allow(Lighthouse::Facilities::V1::Client).to receive(:new).and_return(mock_lighthouse_client)
        allow(mock_lighthouse_client).to receive(:get_facilities).with(facilityIds: 'vha_648').and_return([])
        allow(Rails.logger).to receive(:info)
      end

      it 'returns the station number as fallback' do
        result = adapter.send(:extract_facility_name, resource_with_dispense)
        
        expect(result).to eq('648')
        expect(StatsD).to have_received(:increment).with('unified_health_data.facility_name_cache.miss')
        expect(StatsD).to have_received(:increment).with('unified_health_data.facility_name_fallback.api_miss')
        expect(StatsD).to have_received(:increment).with('unified_health_data.facility_name_fallback.station_number_only')
      end
    end

    context 'when API call fails' do
      let(:mock_lighthouse_client) { instance_double(Lighthouse::Facilities::V1::Client) }

      before do
        allow(Rails.cache).to receive(:read).with('uhd:facility_names:648').and_return(nil)
        allow(Lighthouse::Facilities::V1::Client).to receive(:new).and_return(mock_lighthouse_client)
        allow(mock_lighthouse_client).to receive(:get_facilities).and_raise(StandardError, 'API Error')
        allow(Rails.logger).to receive(:warn)
      end

      it 'logs the error and returns station number' do
        result = adapter.send(:extract_facility_name, resource_with_dispense)
        
        expect(result).to eq('648')
        expect(Rails.logger).to have_received(:warn).with(/Failed to fetch facility name from API for station 648/)
        expect(StatsD).to have_received(:increment).with('unified_health_data.facility_name_fallback.api_error')
        expect(StatsD).to have_received(:increment).with('unified_health_data.facility_name_fallback.station_number_only')
      end
    end

    context 'with multiple dispenses' do
      before do
        allow(Rails.cache).to receive(:read).with('uhd:facility_names:648').and_return('Portland VA Medical Center')
      end

      it 'uses the most recent dispense' do
        result = adapter.send(:extract_facility_name, resource_with_multiple_dispenses)
        
        expect(result).to eq('Portland VA Medical Center')
        expect(Rails.cache).to have_received(:read).with('uhd:facility_names:648')
      end
    end

    context 'when no dispenses exist' do
      it 'returns nil' do
        result = adapter.send(:extract_facility_name, resource_without_dispense)
        
        expect(result).to be_nil
      end
    end

    context 'when dispense has no location' do
      it 'returns nil' do
        result = adapter.send(:extract_facility_name, resource_without_location)
        
        expect(result).to be_nil
      end
    end

    context 'when location display has invalid station number format' do
      it 'returns nil' do
        result = adapter.send(:extract_facility_name, resource_with_invalid_station)
        
        expect(result).to be_nil
      end
    end
  end

  describe '#find_most_recent_medication_dispense' do
    let(:dispenses) do
      [
        {
          'resourceType' => 'MedicationDispense',
          'whenHandedOver' => '2023-01-15T10:00:00Z'
        },
        {
          'resourceType' => 'MedicationDispense',
          'whenHandedOver' => '2023-01-20T14:30:00Z'
        },
        {
          'resourceType' => 'Other',
          'whenHandedOver' => '2023-01-25T14:30:00Z'
        }
      ]
    end

    it 'returns the most recent MedicationDispense' do
      result = adapter.send(:find_most_recent_medication_dispense, dispenses)
      
      expect(result['whenHandedOver']).to eq('2023-01-20T14:30:00Z')
    end

    context 'with no MedicationDispense resources' do
      let(:dispenses) do
        [
          { 'resourceType' => 'Other', 'whenHandedOver' => '2023-01-25T14:30:00Z' }
        ]
      end

      it 'returns nil' do
        result = adapter.send(:find_most_recent_medication_dispense, dispenses)
        
        expect(result).to be_nil
      end
    end

    context 'with nil input' do
      it 'returns nil' do
        result = adapter.send(:find_most_recent_medication_dispense, nil)
        
        expect(result).to be_nil
      end
    end

    context 'with empty array' do
      it 'returns nil' do
        result = adapter.send(:find_most_recent_medication_dispense, [])
        
        expect(result).to be_nil
      end
    end
  end

  describe '#fetch_facility_name_from_api' do
    let(:mock_lighthouse_client) { instance_double(Lighthouse::Facilities::V1::Client) }
    let(:mock_facility) { double('Facility', name: 'Portland VA Medical Center') }

    before do
      allow(Lighthouse::Facilities::V1::Client).to receive(:new).and_return(mock_lighthouse_client)
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:warn)
      allow(StatsD).to receive(:increment)
    end

    context 'when API returns facility' do
      before do
        allow(mock_lighthouse_client).to receive(:get_facilities).with(facilityIds: 'vha_648').and_return([mock_facility])
      end

      it 'returns the facility name' do
        result = adapter.send(:fetch_facility_name_from_api, '648')
        
        expect(result).to eq('Portland VA Medical Center')
        expect(mock_lighthouse_client).to have_received(:get_facilities).with(facilityIds: 'vha_648')
      end
    end

    context 'when API returns empty result' do
      before do
        allow(mock_lighthouse_client).to receive(:get_facilities).with(facilityIds: 'vha_648').and_return([])
      end

      it 'returns nil and logs info' do
        result = adapter.send(:fetch_facility_name_from_api, '648')
        
        expect(result).to be_nil
        expect(Rails.logger).to have_received(:info).with('No facility found for station number 648 in Lighthouse API')
      end
    end

    context 'when API returns nil' do
      before do
        allow(mock_lighthouse_client).to receive(:get_facilities).with(facilityIds: 'vha_648').and_return(nil)
      end

      it 'returns nil and logs info' do
        result = adapter.send(:fetch_facility_name_from_api, '648')
        
        expect(result).to be_nil
        expect(Rails.logger).to have_received(:info).with('No facility found for station number 648 in Lighthouse API')
      end
    end

    context 'when API call raises an error' do
      before do
        allow(mock_lighthouse_client).to receive(:get_facilities).and_raise(StandardError, 'Network error')
      end

      it 'returns nil, logs error, and sends metric' do
        result = adapter.send(:fetch_facility_name_from_api, '648')
        
        expect(result).to be_nil
        expect(Rails.logger).to have_received(:warn).with('Failed to fetch facility name from API for station 648: Network error')
        expect(StatsD).to have_received(:increment).with('unified_health_data.facility_name_fallback.api_error')
      end
    end
  end
end