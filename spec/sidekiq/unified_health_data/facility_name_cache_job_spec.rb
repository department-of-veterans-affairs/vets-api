# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/facilities/v1/client'
require 'lighthouse/facilities/v1/response'

RSpec.describe UnifiedHealthData::FacilityNameCacheJob, type: :job do
  subject(:job) { described_class.new }

  let(:mock_lighthouse_client) { instance_double(Lighthouse::Facilities::V1::Client) }
  let(:mock_response) { instance_double(Lighthouse::Facilities::V1::Response) }
  
  let(:mock_facilities) do
    [
      double('Facility', id: 'vha_648', name: 'Portland VA Medical Center'),
      double('Facility', id: 'vha_556', name: 'Captain James A. Lovell Federal Health Care Center'),
      double('Facility', id: 'vba_123', name: 'Non-VHA Facility'), # Should be filtered out
      double('Facility', id: 'vha_442', name: 'Cheyenne VA Medical Center')
    ]
  end

  before do
    allow(Lighthouse::Facilities::V1::Client).to receive(:new).and_return(mock_lighthouse_client)
    allow(mock_lighthouse_client).to receive(:get_paginated_facilities).and_return(mock_response)
    allow(mock_response).to receive(:facilities).and_return(mock_facilities)
    
    # Mock Rails cache
    allow(Rails.cache).to receive(:write)
    allow(Rails.cache).to receive(:delete)
    
    # Mock time calculations
    allow(Time).to receive(:current).and_return(Time.zone.parse('2023-01-15 02:00:00 EST'))
    
    # Mock StatsD
    allow(StatsD).to receive(:increment)
    allow(StatsD).to receive(:gauge)
    
    # Mock Rails logger
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
  end

  describe '#perform' do
    context 'when successful' do
      it 'fetches VHA facilities and caches them in Rails cache' do
        expect(mock_lighthouse_client).to receive(:get_paginated_facilities).with(
          type: 'health',
          per_page: 1000,
          page: 1
        )
        
        job.perform
        
        # Should cache only VHA facilities (excluding vba_123)
        expect(Rails.cache).to have_received(:write).with('uhd:facility_names:648', 'Portland VA Medical Center', expires_in: 4.hours)
        expect(Rails.cache).to have_received(:write).with('uhd:facility_names:556', 'Captain James A. Lovell Federal Health Care Center', expires_in: 4.hours)
        expect(Rails.cache).to have_received(:write).with('uhd:facility_names:442', 'Cheyenne VA Medical Center', expires_in: 4.hours)
      end

      it 'logs successful completion' do
        job.perform
        
        expect(Rails.logger).to have_received(:info).with('[UnifiedHealthData] - Starting facility name cache refresh')
        expect(Rails.logger).to have_received(:info).with('[UnifiedHealthData] - Cache operation complete: 3 facilities cached')
      end

      it 'sends success metrics to StatsD' do
        job.perform
        
        expect(StatsD).to have_received(:increment).with('unified_health_data.facility_name_cache_job.complete')
        expect(StatsD).to have_received(:gauge).with('unified_health_data.facility_name_cache_job.facilities_cached', 3)
      end
    end

    context 'when an error occurs' do
      before do
        allow(mock_lighthouse_client).to receive(:get_paginated_facilities)
          .and_raise(StandardError, 'API Error')
      end

      it 'logs the error and re-raises' do
        expect { job.perform }.to raise_error('Failed to cache facility names: API Error')
        
        expect(Rails.logger).to have_received(:error)
          .with('[UnifiedHealthData] - Error in UnifiedHealthData::FacilityNameCacheJob: API Error')
        expect(StatsD).to have_received(:increment).with('unified_health_data.facility_name_cache_job.error')
      end
    end

    context 'when no facilities are returned' do
      before do
        allow(mock_response).to receive(:facilities).and_return([])
      end

      it 'does not attempt to cache anything' do
        job.perform
        
        expect(Rails.cache).not_to have_received(:write)
        expect(StatsD).to have_received(:gauge).with('unified_health_data.facility_name_cache_job.facilities_cached', 0)
      end
    end
  end

  describe 'Sidekiq configuration' do
    it 'is configured with proper retry settings' do
      expect(described_class.sidekiq_options_hash['retry']).to eq(3)
    end
  end
end