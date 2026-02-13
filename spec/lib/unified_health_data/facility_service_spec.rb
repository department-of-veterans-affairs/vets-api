# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/facility_service'

RSpec.describe UnifiedHealthData::FacilityService, type: :service do
  subject(:service) { described_class.new }

  describe '#get_facility_timezone' do
    context 'when station_number is blank' do
      it 'returns nil for nil' do
        expect(service.get_facility_timezone(nil)).to be_nil
      end

      it 'returns nil for empty string' do
        expect(service.get_facility_timezone('')).to be_nil
      end
    end

    context 'when facility is found with timezone' do
      before do
        stub_request(:get, %r{/facilities/v2/facilities/668})
          .to_return(
            status: 200,
            body: {
              id: '668',
              name: 'Mann-Grandstaff VA Medical Center',
              timezone: { zoneId: 'America/Los_Angeles' }
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns the timezone ID' do
        expect(service.get_facility_timezone('668')).to eq('America/Los_Angeles')
      end
    end

    context 'when facility is found without timezone' do
      before do
        stub_request(:get, %r{/facilities/v2/facilities/668})
          .to_return(
            status: 200,
            body: {
              id: '668',
              name: 'Mann-Grandstaff VA Medical Center'
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns nil' do
        expect(service.get_facility_timezone('668')).to be_nil
      end
    end

    context 'when facility is not found' do
      before do
        stub_request(:get, %r{/facilities/v2/facilities/999})
          .to_return(status: 404, body: { error: 'Not found' }.to_json)
        allow(Rails.logger).to receive(:warn)
      end

      it 'returns nil' do
        expect(service.get_facility_timezone('999')).to be_nil
      end
    end
  end

  describe '#get_facility_with_cache' do
    let(:facility_id) { '668' }
    let(:cache_key) { "uhd_facility_#{facility_id}" }

    before do
      stub_request(:get, %r{/facilities/v2/facilities/668})
        .to_return(
          status: 200,
          body: { id: '668', name: 'API Facility' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'uses Rails.cache.fetch with correct key, TTL, and skip_nil' do
      expect(Rails.cache).to receive(:fetch)
        .with(cache_key, expires_in: 12.hours, skip_nil: true)
        .and_call_original

      service.get_facility_with_cache(facility_id)
    end

    it 'returns facility data' do
      result = service.get_facility_with_cache(facility_id)
      expect(result[:id]).to eq('668')
    end
  end

  describe '#get_facility' do
    let(:facility_id) { '983' }

    context 'when API returns success' do
      before do
        stub_request(:get, %r{/facilities/v2/facilities/983})
          .to_return(
            status: 200,
            body: {
              id: '983',
              name: 'Cheyenne VA Medical Center',
              timezone: { zoneId: 'America/Denver' }
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns facility data' do
        result = service.get_facility(facility_id)
        expect(result[:id]).to eq('983')
        expect(result[:timezone][:zoneId]).to eq('America/Denver')
      end
    end

    context 'when API returns error' do
      before do
        stub_request(:get, %r{/facilities/v2/facilities/999})
          .to_return(status: 404, body: { error: 'Not found' }.to_json)
      end

      it 'returns nil and logs warning' do
        expect(Rails.logger).to receive(:warn).with(
          /UHD FacilityService error/,
          hash_including(service: 'unified_health_data', facility_id: '999')
        )

        result = service.get_facility('999')
        expect(result).to be_nil
      end
    end

    context 'when API returns invalid JSON' do
      before do
        stub_request(:get, %r{/facilities/v2/facilities/668})
          .to_return(
            status: 200,
            body: 'not valid json {{{',
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns nil and logs warning' do
        expect(Rails.logger).to receive(:warn).with(
          /Failed to parse response body/,
          hash_including(service: 'unified_health_data')
        )

        result = service.get_facility('668')
        expect(result).to be_nil
      end
    end
  end
end
