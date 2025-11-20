# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/adapters/facility_name_resolver'

RSpec.describe UnifiedHealthData::Adapters::FacilityNameResolver do
  subject { described_class.new }

  let(:base_resource) do
    {
      'id' => '123',
      'status' => 'active',
      'resourceType' => 'MedicationRequest'
    }
  end

  let(:dispense_finder) do
    lambda do |contained|
      return nil unless contained.is_a?(Array)

      dispenses = contained.select { |c| c['resourceType'] == 'MedicationDispense' }
      return nil if dispenses.empty?

      dispenses.max_by do |dispense|
        when_handed_over = dispense['whenHandedOver']
        when_handed_over ? Time.zone.parse(when_handed_over) : Time.zone.at(0)
      end
    end
  end

  describe '#extract_facility_name' do
    context 'with MedicationDispense containing station number' do
      let(:resource_with_station_number) do
        base_resource.merge(
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-1',
              'location' => { 'display' => '556-RX-MAIN-OP' }
            }
          ]
        )
      end

      context 'when facility name is cached' do
        before do
          allow(Rails.cache).to receive(:read).with('uhd:facility_names:556').and_return('Cached Facility Name')
          allow(Rails.cache).to receive(:exist?).with('uhd:facility_names:556').and_return(true)
        end

        it 'returns the cached facility name' do
          result = subject.extract_facility_name(resource_with_station_number, dispense_finder)
          expect(result).to eq('Cached Facility Name')
        end

        it 'does not call the API when cache hit occurs' do
          mock_client = instance_double(Lighthouse::Facilities::V1::Client)
          allow(Lighthouse::Facilities::V1::Client).to receive(:new).and_return(mock_client)
          expect(mock_client).not_to receive(:get_facilities)

          subject.extract_facility_name(resource_with_station_number, dispense_finder)
        end
      end

      context 'when facility name is not cached' do
        before do
          allow(Rails.cache).to receive(:read).with('uhd:facility_names:556').and_return(nil)
          allow(Rails.cache).to receive(:write)
          allow(Rails.cache).to receive(:exist?).with('uhd:facility_names:556').and_return(false)
        end

        it 'calls the API and returns the facility name' do
          mock_client = instance_double(Lighthouse::Facilities::V1::Client)
          mock_facility = double('facility', name: 'API Facility Name')
          allow(Lighthouse::Facilities::V1::Client).to receive(:new).and_return(mock_client)
          allow(mock_client).to receive(:get_facilities).with(facilityIds: 'vha_556').and_return([mock_facility])

          result = subject.extract_facility_name(resource_with_station_number, dispense_finder)
          expect(result).to eq('API Facility Name')
          expect(mock_client).to have_received(:get_facilities).with(facilityIds: 'vha_556')
        end
      end

      context 'when 3-digit lookup misses but full facility identifier exists' do
        let(:resource_with_extended_station) do
          base_resource.merge(
            'contained' => [
              {
                'resourceType' => 'MedicationDispense',
                'id' => 'dispense-extended',
                'location' => { 'display' => '648A4-RX-MAIN' }
              }
            ]
          )
        end

        before do
          allow(Rails.cache).to receive(:read).with('uhd:facility_names:648').and_return(nil)
          allow(Rails.cache).to receive(:read).with('uhd:facility_names:648A4').and_return('Full Station Facility')
          allow(Rails.cache).to receive(:exist?).with('uhd:facility_names:648').and_return(false)
          allow(Rails.cache).to receive(:exist?).with('uhd:facility_names:648A4').and_return(true)
        end

        it 'falls back to the full station identifier' do
          result = subject.extract_facility_name(resource_with_extended_station, dispense_finder)
          expect(result).to eq('Full Station Facility')
        end
      end

      context 'when extended station identifier is invalid' do
        let(:resource_with_invalid_station) do
          base_resource.merge(
            'contained' => [
              {
                'resourceType' => 'MedicationDispense',
                'id' => 'dispense-invalid',
                'location' => { 'display' => 'ABC-RX-MAIN' }
              }
            ]
          )
        end

        it 'returns nil without attempting lookup' do
          expect(subject.extract_facility_name(resource_with_invalid_station, dispense_finder)).to be_nil
        end
      end

      context 'when API returns nil' do
        before do
          allow(Rails.cache).to receive(:read).with('uhd:facility_names:556').and_return(nil)
          allow(Rails.cache).to receive(:write)
          allow(Rails.logger).to receive(:warn)
          allow(StatsD).to receive(:increment)
          allow(Rails.cache).to receive(:exist?).with('uhd:facility_names:556').and_return(false)
        end

        it 'returns nil when API call returns empty array' do
          mock_client = instance_double(Lighthouse::Facilities::V1::Client)
          allow(Lighthouse::Facilities::V1::Client).to receive(:new).and_return(mock_client)
          allow(mock_client).to receive(:get_facilities).with(facilityIds: 'vha_556').and_return([])

          result = subject.extract_facility_name(resource_with_station_number, dispense_finder)
          expect(result).to be_nil
        end
      end
    end

    context 'with MedicationDispense containing non-standard station format' do
      let(:resource_with_short_station) do
        base_resource.merge(
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-1',
              'location' => { 'display' => '12-PHARMACY' }
            }
          ]
        )
      end

      before do
        allow(Rails.logger).to receive(:error)
      end

      it 'returns nil when station number does not match 3-digit pattern' do
        result = subject.extract_facility_name(resource_with_short_station, dispense_finder)
        expect(Rails.logger).to have_received(:error).with(
          'Unable to extract valid station number from: 12-PHARMACY'
        )
        expect(result).to be_nil
      end
    end

    context 'with no MedicationDispense in contained resources' do
      let(:resource_without_dispense) do
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

      it 'returns nil when no MedicationDispense found' do
        result = subject.extract_facility_name(resource_without_dispense, dispense_finder)
        expect(result).to be_nil
      end
    end

    context 'with MedicationDispense but no location' do
      let(:resource_no_location) do
        base_resource.merge(
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-1'
            }
          ]
        )
      end

      it 'returns nil when MedicationDispense has no location' do
        result = subject.extract_facility_name(resource_no_location, dispense_finder)
        expect(result).to be_nil
      end
    end

    context 'with multiple MedicationDispense resources' do
      let(:resource_multiple_dispenses) do
        base_resource.merge(
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-1',
              'location' => { 'display' => '442-RX-MAIN' },
              'whenHandedOver' => '2025-01-15T10:00:00Z'
            },
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-2',
              'location' => { 'display' => '556-RX-MAIN-OP' },
              'whenHandedOver' => '2025-01-20T10:00:00Z'
            }
          ]
        )
      end

      before do
        allow(Rails.cache).to receive(:read).with('uhd:facility_names:556').and_return('Recent Facility')
        allow(Rails.cache).to receive(:exist?).with('uhd:facility_names:556').and_return(true)
      end

      it 'uses the most recent MedicationDispense for station number' do
        result = subject.extract_facility_name(resource_multiple_dispenses, dispense_finder)
        expect(result).to eq('Recent Facility')
      end
    end

    context 'with no contained resources' do
      it 'returns nil when no contained resources exist' do
        result = subject.extract_facility_name(base_resource, dispense_finder)
        expect(result).to be_nil
      end
    end
  end

  describe '#lookup' do
    let(:mock_client) { instance_double(Lighthouse::Facilities::V1::Client) }
    let(:mock_facility) { double('facility', name: 'Test VA Medical Center') }

    before do
      allow(Lighthouse::Facilities::V1::Client).to receive(:new).and_return(mock_client)
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:warn)
      allow(StatsD).to receive(:increment)
    end

    context 'when facility name is cached' do
      before do
        allow(Rails.cache).to receive(:read).with('uhd:facility_names:556').and_return('Cached Name')
        allow(Rails.cache).to receive(:exist?).with('uhd:facility_names:556').and_return(true)
      end

      it 'returns cached value without calling API' do
        result = subject.lookup('556')
        expect(result).to eq('Cached Name')
        expect(mock_client).not_to receive(:get_facilities)
      end
    end

    context 'when station_identifier is blank' do
      it 'returns nil for nil' do
        expect(subject.lookup(nil)).to be_nil
      end

      it 'returns nil for empty string' do
        expect(subject.lookup('')).to be_nil
      end
    end

    context 'when facility name is not cached' do
      before do
        allow(Rails.cache).to receive(:read).with('uhd:facility_names:556').and_return(nil)
        allow(Rails.cache).to receive(:exist?).with('uhd:facility_names:556').and_return(false)
        allow(Rails.cache).to receive(:write)
      end

      it 'fetches from API and returns facility name' do
        allow(mock_client).to receive(:get_facilities).with(facilityIds: 'vha_556').and_return([mock_facility])

        result = subject.lookup('556')
        expect(result).to eq('Test VA Medical Center')
      end
    end
  end

  describe '#fetch_from_api (private)' do
    let(:mock_client) { instance_double(Lighthouse::Facilities::V1::Client) }
    let(:mock_facility) { double('facility', name: 'Test VA Medical Center') }

    before do
      allow(Lighthouse::Facilities::V1::Client).to receive(:new).and_return(mock_client)
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:warn)
      allow(StatsD).to receive(:increment)
    end

    context 'when API returns facility data' do
      before do
        allow(mock_client).to receive(:get_facilities).with(facilityIds: 'vha_556').and_return([mock_facility])
        allow(Rails.cache).to receive(:write)
      end

      it 'returns the facility name' do
        result = subject.send(:fetch_from_api, '556')
        expect(result).to eq('Test VA Medical Center')
      end

      it 'calls the Lighthouse API with correct facility ID format' do
        subject.send(:fetch_from_api, '556')
        expect(mock_client).to have_received(:get_facilities).with(facilityIds: 'vha_556')
      end

      it 'writes the facility name to cache with TTL' do
        subject.send(:fetch_from_api, '556')
        expect(Rails.cache).to have_received(:write).with(
          'uhd:facility_names:556',
          'Test VA Medical Center',
          expires_in: 4.hours
        )
      end
    end

    context 'when API returns empty array' do
      before do
        allow(mock_client).to receive(:get_facilities).with(facilityIds: 'vha_556').and_return([])
        allow(Rails.cache).to receive(:write)
      end

      it 'returns nil and logs warning message' do
        result = subject.send(:fetch_from_api, '556')
        expect(result).to be_nil
        expect(Rails.logger).to have_received(:warn).with(
          'No facility found for station number 556 in Lighthouse API'
        )
      end

      it 'caches nil result to avoid repeated API calls' do
        subject.send(:fetch_from_api, '556')
        expect(Rails.cache).to have_received(:write).with(
          'uhd:facility_names:556',
          nil,
          expires_in: 4.hours
        )
      end
    end

    context 'when API returns nil' do
      before do
        allow(mock_client).to receive(:get_facilities).with(facilityIds: 'vha_556').and_return(nil)
      end

      it 'returns nil and logs warning message' do
        result = subject.send(:fetch_from_api, '556')
        expect(result).to be_nil
        expect(Rails.logger).to have_received(:warn).with(
          'No facility found for station number 556 in Lighthouse API'
        )
      end
    end

    context 'when API raises an exception' do
      let(:api_error) { StandardError.new('API connection failed') }

      before do
        allow(mock_client).to receive(:get_facilities).and_raise(api_error)
        allow(Rails.cache).to receive(:write)
        allow(Rails.logger).to receive(:error)
      end

      it 'returns nil, logs error, and increments StatsD metric' do
        result = subject.send(:fetch_from_api, '556')

        expect(result).to be_nil
        expect(Rails.logger).to have_received(:error).with(
          'Failed to fetch facility name from API for station 556: API connection failed'
        )
        expect(StatsD).to have_received(:increment).with(
          'unified_health_data.facility_name_fallback.api_error'
        )
      end

      it 'does not cache error results' do
        subject.send(:fetch_from_api, '556')
        expect(Rails.cache).not_to have_received(:write)
      end
    end

    context 'when API returns facility without name' do
      let(:facility_without_name) { double('facility', name: nil) }

      before do
        allow(mock_client).to receive(:get_facilities).with(facilityIds: 'vha_556').and_return([facility_without_name])
      end

      it 'returns nil when facility name is nil' do
        result = subject.send(:fetch_from_api, '556')
        expect(result).to be_nil
      end
    end

    context 'when API returns multiple facilities' do
      let(:facility_one) { double('facility', name: 'First Facility') }
      let(:facility_two) { double('facility', name: 'Second Facility') }

      before do
        allow(mock_client).to receive(:get_facilities).with(facilityIds: 'vha_556').and_return([facility_one,
                                                                                                facility_two])
      end

      it 'returns the name of the first facility' do
        result = subject.send(:fetch_from_api, '556')
        expect(result).to eq('First Facility')
      end
    end
  end
end
