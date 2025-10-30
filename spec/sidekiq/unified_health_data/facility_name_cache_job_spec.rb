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
    allow(mock_response).to receive_messages(facilities: mock_facilities, links: nil) # No next page by default

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
        expect(Rails.cache).to have_received(:write).with('uhd:facility_names:648', 'Portland VA Medical Center',
                                                          expires_in: 4.hours)
        expect(Rails.cache).to have_received(:write).with('uhd:facility_names:556',
                                                          'Captain James A. Lovell Federal Health Care Center',
                                                          expires_in: 4.hours)
        expect(Rails.cache).to have_received(:write).with('uhd:facility_names:442', 'Cheyenne VA Medical Center',
                                                          expires_in: 4.hours)
      end

      it 'logs successful completion' do
        job.perform

        expect(Rails.logger).to have_received(:info).with(
          '[UnifiedHealthData] - Cache operation complete: 3 facilities cached'
        )
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

    context 'when multiple pages of facilities exist' do
      let(:first_page_response) { instance_double(Lighthouse::Facilities::V1::Response) }
      let(:second_page_response) { instance_double(Lighthouse::Facilities::V1::Response) }
      let(:batch_size) { UnifiedHealthData::FacilityNameCacheJob::BATCH_SIZE }

      before do
        first_page_facilities = [
          double('Facility', id: 'vha_001', name: 'Facility 1'),
          double('Facility', id: 'vha_002', name: 'Facility 2')
        ]
        second_page_facilities = [
          double('Facility', id: 'vha_003', name: 'Facility 3')
        ]

        allow(first_page_response).to receive_messages(facilities: first_page_facilities, links: {
                                                         'next' => 'https://api.va.gov/services/va_facilities/v1/facilities?type=health&page=2&per_page=1000'
                                                       })

        allow(second_page_response).to receive_messages(facilities: second_page_facilities, links: nil) # No next page

        allow(mock_lighthouse_client).to receive(:get_paginated_facilities).and_return(
          first_page_response,
          second_page_response
        )
      end

      it 'requests subsequent pages using links.next until no next link is present' do
        job.perform

        expect(mock_lighthouse_client).to have_received(:get_paginated_facilities).with(
          type: 'health',
          per_page: batch_size,
          page: 1
        )
        expect(mock_lighthouse_client).to have_received(:get_paginated_facilities).with(
          type: 'health',
          page: '2',
          per_page: '1000'
        )
      end
    end
  end

  describe 'Sidekiq configuration' do
    it 'is configured with proper retry settings' do
      expect(described_class.sidekiq_options_hash['retry']).to eq(3)
    end
  end
end
