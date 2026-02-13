# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/adapters/facility_name_resolver'

RSpec.describe UnifiedHealthData::Adapters::FacilityNameResolver do
  subject { described_class.new }

  # Use the actual configuration format: array of [min, max] pairs
  let(:facility_range) { [[358, 718], [720, 740], [742, 758]] }

  before do
    allow(Settings.mhv).to receive(:facility_range).and_return(facility_range)
  end

  describe '#extract_station_number' do
    context 'with valid 3-digit station number in range' do
      let(:dispense) do
        {
          'resourceType' => 'MedicationDispense',
          'location' => { 'display' => '556-RX-MAIN-OP' }
        }
      end

      before do
        allow(HealthFacility).to receive(:exists?).with(unique_id: '556').and_return(true)
      end

      it 'extracts and returns the 3-digit station number' do
        expect(subject.extract_station_number(dispense)).to eq('556')
      end

      it 'does not log warnings' do
        expect(Rails.logger).not_to receive(:warn)
        subject.extract_station_number(dispense)
      end

      it 'does not increment StatsD counter' do
        expect(StatsD).not_to receive(:increment)
        subject.extract_station_number(dispense)
      end
    end

    context 'with invalid 3-digit station number out of range' do
      let(:dispense) do
        {
          'resourceType' => 'MedicationDispense',
          'location' => { 'display' => '005-SOME-LOCATION' }
        }
      end

      before do
        allow(HealthFacility).to receive(:exists?).and_return(false)
        allow(Rails.logger).to receive(:warn)
        allow(StatsD).to receive(:increment)
      end

      it 'returns nil' do
        expect(subject.extract_station_number(dispense)).to be_nil
      end

      it 'logs warning with extraction details' do
        subject.extract_station_number(dispense)
        expect(Rails.logger).to have_received(:warn).with(
          hash_including(
            message: 'Unable to extract valid station number from Oracle Health location',
            location_display: '005-SOME-LOCATION',
            three_digit_candidate: '005',
            service: 'unified_health_data'
          )
        )
      end

      it 'increments StatsD counter with candidate tag' do
        subject.extract_station_number(dispense)
        expect(StatsD).to have_received(:increment).with(
          'unified_health_data.oracle_health.invalid_station_number',
          tags: ['candidate:005']
        )
      end
    end

    context 'with invalid 3-digit station numbers from production errors' do
      let(:invalid_stations) { %w[080 000 004 026 070 003] }

      before do
        allow(HealthFacility).to receive(:exists?).and_return(false)
        allow(Rails.logger).to receive(:warn)
        allow(StatsD).to receive(:increment)
      end

      it 'returns nil for all invalid stations' do
        invalid_stations.each do |station|
          dispense = {
            'resourceType' => 'MedicationDispense',
            'location' => { 'display' => "#{station}-RX-MAIN" }
          }
          expect(subject.extract_station_number(dispense)).to be_nil
        end
      end

      it 'logs each invalid station attempt' do
        dispense = {
          'resourceType' => 'MedicationDispense',
          'location' => { 'display' => '080-RX-MAIN' }
        }
        subject.extract_station_number(dispense)
        expect(Rails.logger).to have_received(:warn)
        expect(StatsD).to have_received(:increment)
      end
    end

    context 'with valid extended station identifier' do
      let(:dispense) do
        {
          'resourceType' => 'MedicationDispense',
          'location' => { 'display' => '648A4-PHARMACY' }
        }
      end

      before do
        # 3-digit fails validation, but extended identifier succeeds
        allow(HealthFacility).to receive(:exists?).with(unique_id: '648').and_return(false)
        allow(HealthFacility).to receive(:exists?).with(unique_id: '648A4').and_return(true)
      end

      it 'falls back to extended identifier when 3-digit fails' do
        expect(subject.extract_station_number(dispense)).to eq('648A4')
      end
    end

    context 'with invalid extended station identifier format' do
      let(:dispense) do
        {
          'resourceType' => 'MedicationDispense',
          'location' => { 'display' => '648ABCD-PHARMACY' }
        }
      end

      before do
        allow(HealthFacility).to receive(:exists?).and_return(false)
        allow(Rails.logger).to receive(:warn)
        allow(StatsD).to receive(:increment)
      end

      it 'returns nil when extended identifier is too long' do
        expect(subject.extract_station_number(dispense)).to be_nil
      end

      it 'logs the invalid extended identifier' do
        subject.extract_station_number(dispense)
        expect(Rails.logger).to have_received(:warn).with(
          hash_including(
            full_identifier_candidate: '648ABCD'
          )
        )
      end
    end

    context 'with non-numeric location prefix' do
      let(:dispense) do
        {
          'resourceType' => 'MedicationDispense',
          'location' => { 'display' => 'ABC-PHARMACY' }
        }
      end

      before do
        allow(Rails.logger).to receive(:warn)
        allow(StatsD).to receive(:increment)
      end

      it 'returns nil' do
        expect(subject.extract_station_number(dispense)).to be_nil
      end

      it 'logs with nil three_digit_candidate' do
        subject.extract_station_number(dispense)
        expect(Rails.logger).to have_received(:warn).with(
          hash_including(
            three_digit_candidate: nil
          )
        )
      end

      it 'increments StatsD with "none" tag' do
        subject.extract_station_number(dispense)
        expect(StatsD).to have_received(:increment).with(
          'unified_health_data.oracle_health.invalid_station_number',
          tags: ['candidate:none']
        )
      end
    end

    context 'with station in range but not in HealthFacility table' do
      let(:dispense) do
        {
          'resourceType' => 'MedicationDispense',
          'location' => { 'display' => '400-RX-MAIN' }
        }
      end

      before do
        allow(HealthFacility).to receive(:exists?).and_return(false)
        allow(Rails.logger).to receive(:warn)
        allow(StatsD).to receive(:increment)
      end

      it 'returns nil because HealthFacility validation is also required' do
        # Station 400 is in range [358, 718], but still fails because
        # it must ALSO exist in HealthFacility table (AND logic with range check)
        expect(subject.extract_station_number(dispense)).to be_nil
      end
    end

    context 'with station out of range but in HealthFacility table' do
      let(:dispense) do
        {
          'resourceType' => 'MedicationDispense',
          'location' => { 'display' => '005-SOME-LOCATION' }
        }
      end

      before do
        allow(HealthFacility).to receive(:exists?).with(unique_id: '005').and_return(true)
        allow(HealthFacility).to receive(:exists?).with(unique_id: '5').and_return(false)
        allow(Rails.logger).to receive(:warn)
        allow(StatsD).to receive(:increment)
      end

      it 'returns nil because range check fails before HealthFacility check' do
        # Station 005 (numeric 5) is not in any range, so range check returns false early
        # HealthFacility check never happens
        expect(subject.extract_station_number(dispense)).to be_nil
      end
    end

    context 'with station in a gap between ranges' do
      let(:dispense) do
        {
          'resourceType' => 'MedicationDispense',
          'location' => { 'display' => '719-RX-MAIN' }
        }
      end

      before do
        allow(HealthFacility).to receive(:exists?).and_return(false)
        allow(Rails.logger).to receive(:warn)
        allow(StatsD).to receive(:increment)
      end

      it 'returns nil because station is in a gap between ranges' do
        # Station 719 falls in gap between [358-718] and [720-740]
        expect(subject.extract_station_number(dispense)).to be_nil
      end
    end

    context 'with station in second range' do
      let(:dispense) do
        {
          'resourceType' => 'MedicationDispense',
          'location' => { 'display' => '730-RX-MAIN' }
        }
      end

      before do
        allow(HealthFacility).to receive(:exists?).with(unique_id: '730').and_return(true)
      end

      it 'validates correctly when station is in second range [720-740]' do
        expect(subject.extract_station_number(dispense)).to eq('730')
      end
    end

    context 'with station in third range' do
      let(:dispense) do
        {
          'resourceType' => 'MedicationDispense',
          'location' => { 'display' => '750-RX-MAIN' }
        }
      end

      before do
        allow(HealthFacility).to receive(:exists?).with(unique_id: '750').and_return(true)
      end

      it 'validates correctly when station is in third range [742-758]' do
        expect(subject.extract_station_number(dispense)).to eq('750')
      end
    end

    context 'when HealthFacility validation raises an error' do
      let(:dispense) do
        {
          'resourceType' => 'MedicationDispense',
          'location' => { 'display' => '556-RX-MAIN' }
        }
      end

      before do
        allow(HealthFacility).to receive(:exists?).and_raise(StandardError, 'Database error')
        allow(Rails.logger).to receive(:error)
        allow(Rails.logger).to receive(:warn)
        allow(StatsD).to receive(:increment)
      end

      it 'logs error and returns nil' do
        result = subject.extract_station_number(dispense)
        expect(result).to be_nil
        expect(Rails.logger).to have_received(:error).with(
          'Error validating station number 556: Database error'
        )
      end
    end

    context 'with nil dispense' do
      it 'returns nil' do
        expect(subject.extract_station_number(nil)).to be_nil
      end
    end

    context 'with dispense missing location' do
      let(:dispense) do
        { 'resourceType' => 'MedicationDispense' }
      end

      it 'returns nil' do
        expect(subject.extract_station_number(dispense)).to be_nil
      end
    end

    context 'with dispense missing location.display' do
      let(:dispense) do
        {
          'resourceType' => 'MedicationDispense',
          'location' => {}
        }
      end

      it 'returns nil' do
        expect(subject.extract_station_number(dispense)).to be_nil
      end
    end
  end

  describe '#resolve_facility_name' do
    context 'with valid station number' do
      let(:dispense) do
        {
          'resourceType' => 'MedicationDispense',
          'location' => { 'display' => '556-RX-MAIN-OP' }
        }
      end

      before do
        allow(HealthFacility).to receive(:exists?).with(unique_id: '556').and_return(true)
        allow(Rails.cache).to receive(:read).with('uhd:facility_names:556').and_return('VA Test Medical Center')
        allow(Rails.cache).to receive(:exist?).with('uhd:facility_names:556').and_return(true)
      end

      it 'extracts station number and looks up facility name' do
        result = subject.resolve_facility_name(dispense)
        expect(result).to eq('VA Test Medical Center')
      end
    end

    context 'with invalid station number' do
      let(:dispense) do
        {
          'resourceType' => 'MedicationDispense',
          'location' => { 'display' => '005-SOME-LOCATION' }
        }
      end

      before do
        allow(HealthFacility).to receive(:exists?).and_return(false)
        allow(Rails.logger).to receive(:warn)
        allow(StatsD).to receive(:increment)
      end

      it 'returns nil without attempting lookup' do
        expect(Rails.cache).not_to receive(:read)
        expect(subject.resolve_facility_name(dispense)).to be_nil
      end
    end

    context 'with valid station but facility not found' do
      let(:dispense) do
        {
          'resourceType' => 'MedicationDispense',
          'location' => { 'display' => '556-RX-MAIN-OP' }
        }
      end

      let(:mock_client) { instance_double(Lighthouse::Facilities::V1::Client) }

      before do
        allow(HealthFacility).to receive(:exists?).with(unique_id: '556').and_return(true)
        allow(Rails.cache).to receive_messages(
          read: nil,
          exist?: false
        )
        allow(Rails.cache).to receive(:write)
        allow(Lighthouse::Facilities::V1::Client).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive(:get_facilities).and_return([])
        allow(Rails.logger).to receive(:warn)
      end

      it 'returns nil when lookup finds no facility' do
        expect(subject.resolve_facility_name(dispense)).to be_nil
      end
    end

    context 'with nil dispense' do
      it 'returns nil' do
        expect(subject.resolve_facility_name(nil)).to be_nil
      end
    end
  end

  describe '#lookup' do
    let(:mock_client) { instance_double(Lighthouse::Facilities::V1::Client) }
    let(:mock_facility) { double('facility', name: 'Test VA Medical Center') }

    before do
      allow(Lighthouse::Facilities::V1::Client).to receive(:new).and_return(mock_client)
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

      it 'caches the result' do
        allow(mock_client).to receive(:get_facilities).with(facilityIds: 'vha_556').and_return([mock_facility])

        subject.lookup('556')
        expect(Rails.cache).to have_received(:write).with(
          'uhd:facility_names:556',
          'Test VA Medical Center',
          expires_in: 4.hours
        )
      end
    end

    context 'when API returns empty array' do
      before do
        allow(Rails.cache).to receive(:read).with('uhd:facility_names:556').and_return(nil)
        allow(Rails.cache).to receive(:exist?).with('uhd:facility_names:556').and_return(false)
        allow(Rails.cache).to receive(:write)
        allow(Rails.logger).to receive(:warn)
        allow(mock_client).to receive(:get_facilities).and_return([])
      end

      it 'returns nil and logs warning' do
        result = subject.lookup('556')
        expect(result).to be_nil
        expect(Rails.logger).to have_received(:warn)
      end

      it 'caches nil result to avoid repeated API calls' do
        subject.lookup('556')
        expect(Rails.cache).to have_received(:write).with(
          'uhd:facility_names:556',
          nil,
          expires_in: 4.hours
        )
      end
    end

    context 'when API raises an exception' do
      let(:api_error) { StandardError.new('API connection failed') }

      before do
        allow(Rails.cache).to receive(:read).with('uhd:facility_names:556').and_return(nil)
        allow(Rails.cache).to receive(:exist?).with('uhd:facility_names:556').and_return(false)
        allow(mock_client).to receive(:get_facilities).and_raise(api_error)
        allow(Rails.logger).to receive(:error)
        allow(StatsD).to receive(:increment)
      end

      it 'returns nil and logs error' do
        result = subject.lookup('556')

        expect(result).to be_nil
        expect(Rails.logger).to have_received(:error).with(
          'Failed to fetch facility name from API for station 556: API connection failed'
        )
        expect(StatsD).to have_received(:increment).with(
          'unified_health_data.facility_name_fallback.api_error'
        )
      end
    end
  end
end
