# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/concerns/facility_cache_warming'
require 'unified_health_data/facility_service'

RSpec.describe UnifiedHealthData::Concerns::FacilityCacheWarming do
  subject(:instance) { test_class.new(adapter) }

  let(:adapter) { double('LabOrTestAdapter') }
  let(:facility_service) { instance_double(UnifiedHealthData::FacilityService) }

  let(:test_class) do
    Class.new do
      include UnifiedHealthData::Concerns::FacilityCacheWarming

      attr_reader :lab_or_test_adapter

      def initialize(adapter)
        @lab_or_test_adapter = adapter
      end
    end
  end

  before do
    allow(Rails.logger).to receive(:info)
    allow(StatsD).to receive(:gauge)
    allow(UnifiedHealthData::FacilityService).to receive(:new).and_return(facility_service)
    allow(facility_service).to receive(:get_facility_with_cache)
  end

  describe '#prewarm_facility_cache' do
    context 'when records are blank' do
      it 'returns early without logging or fetching' do
        instance.send(:prewarm_facility_cache, [])

        expect(Rails.logger).not_to have_received(:info)
        expect(facility_service).not_to have_received(:get_facility_with_cache)
      end

      it 'handles nil records' do
        instance.send(:prewarm_facility_cache, nil)

        expect(Rails.logger).not_to have_received(:info)
      end
    end

    context 'when records have station numbers' do
      let(:records) do
        [
          { 'resource' => { 'id' => '1' } },
          { 'resource' => { 'id' => '2' } },
          { 'resource' => { 'id' => '3' } }
        ]
      end

      before do
        allow(adapter).to receive(:extract_station_number_from_record)
          .and_return('358', '358', '442')
      end

      it 'fetches each unique station number once' do
        instance.send(:prewarm_facility_cache, records)

        expect(facility_service).to have_received(:get_facility_with_cache).with('358').once
        expect(facility_service).to have_received(:get_facility_with_cache).with('442').once
      end

      it 'logs cache pre-warming metrics' do
        instance.send(:prewarm_facility_cache, records)

        expect(Rails.logger).to have_received(:info).with(
          'UHD FacilityService: Pre-warming cache for facility timezones',
          hash_including(
            service: 'unified_health_data',
            total_records: 3,
            records_with_station_number: 3,
            records_without_station_number: 0,
            unique_station_numbers: 2
          )
        )
      end

      it 'emits a StatsD gauge for station number coverage' do
        instance.send(:prewarm_facility_cache, records)

        expect(StatsD).to have_received(:gauge)
          .with('api.uhd.facility.station_number_coverage', 100.0, tags: ['source:labs'])
      end
    end

    context 'when some records lack station numbers' do
      let(:records) do
        [
          { 'resource' => { 'id' => '1' } },
          { 'resource' => { 'id' => '2' } }
        ]
      end

      before do
        allow(adapter).to receive(:extract_station_number_from_record)
          .and_return('358', nil)
      end

      it 'only fetches for records with station numbers' do
        instance.send(:prewarm_facility_cache, records)

        expect(facility_service).to have_received(:get_facility_with_cache).with('358').once
        expect(facility_service).to have_received(:get_facility_with_cache).once
      end

      it 'reports correct coverage percentage' do
        instance.send(:prewarm_facility_cache, records)

        expect(StatsD).to have_received(:gauge)
          .with('api.uhd.facility.station_number_coverage', 50.0, tags: ['source:labs'])
      end
    end
  end
end
