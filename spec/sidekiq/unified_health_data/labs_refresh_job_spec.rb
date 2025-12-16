# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/service'

Sidekiq::Testing.fake!

RSpec.describe UnifiedHealthData::LabsRefreshJob, type: :job do
  let(:user) { create(:user, :loa3) }
  let(:uhd_service) { instance_double(UnifiedHealthData::Service) }
  let(:labs_data) { [instance_double(UnifiedHealthData::LabOrTest)] }

  before do
    allow(User).to receive(:find).with(user.uuid).and_return(user)
    allow(UnifiedHealthData::Service).to receive(:new).with(user).and_return(uhd_service)
    allow(uhd_service).to receive(:get_labs).and_return(labs_data)
    allow(StatsD).to receive(:gauge)
  end

  describe '#perform' do
    context 'when the user exists' do
      it 'fetches labs data using the configured date range' do
        end_date = Date.current
        days_back = Settings.mhv.uhd.labs_logging_date_range_days.to_i
        start_date = end_date - days_back.days

        expect(uhd_service).to receive(:get_labs).with(
          start_date: start_date.strftime('%Y-%m-%d'),
          end_date: end_date.strftime('%Y-%m-%d')
        )

        described_class.new.perform(user.uuid)
      end

      it 'respects custom date range configuration' do
        allow(Settings.mhv.uhd).to receive(:labs_logging_date_range_days).and_return(7)

        end_date = Date.current
        start_date = end_date - 7.days

        expect(uhd_service).to receive(:get_labs).with(
          start_date: start_date.strftime('%Y-%m-%d'),
          end_date: end_date.strftime('%Y-%m-%d')
        )

        described_class.new.perform(user.uuid)
      end

      it 'logs successful completion' do
        expect(Rails.logger).to receive(:info).with(
          'UHD Labs Refresh Job completed successfully',
          hash_including(
            records_count: labs_data.size
          )
        )

        described_class.new.perform(user.uuid)
      end

      it 'returns the count of records fetched' do
        result = described_class.new.perform(user.uuid)
        expect(result).to eq(labs_data.size)
      end

      it 'sends labs count metric to StatsD' do
        described_class.new.perform(user.uuid)

        expect(StatsD).to have_received(:gauge).with('unified_health_data.labs_refresh_job.labs_count', labs_data.size)
      end
    end

    context 'when the user does not exist' do
      it 'logs an error and returns early' do
        allow(User).to receive(:find).with('nonexistent_uuid').and_return(nil)

        expect(Rails.logger).to receive(:error).with(
          'UHD Labs Refresh Job: User not found for UUID: nonexistent_uuid'
        )

        described_class.new.perform('nonexistent_uuid')
      end
    end

    context 'when the service raises an error' do
      let(:error_message) { 'Service unavailable' }

      before do
        allow(uhd_service).to receive(:get_labs).and_raise(StandardError.new(error_message))
      end

      it 'logs the error and re-raises' do
        expect(Rails.logger).to receive(:error).with(
          'UHD Labs Refresh Job failed',
          hash_including(
            error: error_message
          )
        )

        expect { described_class.new.perform(user.uuid) }.to raise_error(StandardError, error_message)
      end
    end
  end

  describe 'sidekiq options' do
    it 'has a retry count of 0' do
      expect(described_class.get_sidekiq_options['retry']).to eq(0)
    end
  end
end
