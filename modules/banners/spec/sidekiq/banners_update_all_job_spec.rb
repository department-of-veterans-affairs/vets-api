# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe Banners::UpdateAllJob, type: :job do
  let(:job) { described_class.new }

  before do
    allow(Flipper).to receive(:enabled?).with(:banner_update_alternative_banners).and_return(true)
    allow(Banners).to receive(:update_all)
    allow(StatsD).to receive(:increment)
    allow(Rails.logger).to receive(:error)
  end

  describe '#perform' do
    context 'when :banner_update_alternative_banners enabled' do
      it 'calls Banners.update_all' do
        job.perform
        expect(Banners).to have_received(:update_all)
      end
    end

    context 'when :banner_update_alternative_banners disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:banner_update_alternative_banners).and_return(false)
      end

      it 'does not call Banners.update_all' do
        job.perform
        expect(Banners).not_to have_received(:update_all)
      end
    end

    context 'when Banners::Updater::BannerDataFetchError is raised' do
      before do
        allow(Banners).to receive(:update_all).and_raise(Banners::Updater::BannerDataFetchError.new('Fetch error'))
      end

      it 'increments the banner_data_fetch_error metric' do
        job.perform
        expect(StatsD).to have_received(:increment).with('banners.sidekiq.update_all_banners.banner_data_fetch_error')
      end

      it 'logs the error as a warning and returns false to avoid retrying' do
        expect(Rails.logger).to receive(:warn).with(
          'Banner data fetch failed',
          { error_message: 'Fetch error', error_class: 'Banners::Updater::BannerDataFetchError' }
        )
        expect(job.perform).to be(false)
      end
    end
  end

  describe 'sidekiq_retries_exhausted' do
    let(:msg) do
      {
        'jid' => '123',
        'class' => 'Banners::UpdateAllJob',
        'error_class' => 'SomeError',
        'error_message' => 'Something went wrong'
      }
    end

    it 'increments the exhausted metric' do
      described_class.sidekiq_retries_exhausted_block.call(msg, nil)
      expect(StatsD).to have_received(:increment).with('banners.sidekiq.update_all_banners.exhausted')
    end

    it 'logs the retries exhausted message' do
      described_class.sidekiq_retries_exhausted_block.call(msg, nil)
      expect(Rails.logger).to have_received(:error).with(
        'Banners::UpdateAllJob retries exhausted',
        { job_id: '123', error_class: 'SomeError', error_message: 'Something went wrong' }
      )
    end

    context 'when an error occurs in the retries exhausted block' do
      before do
        allow(Rails.logger).to receive(:error).and_raise(StandardError.new('Logging error'))
      end

      it 'logs the failure and raises the error' do
        expect do
          described_class.sidekiq_retries_exhausted_block.call(msg, nil)
        end.to raise_error(StandardError, 'Logging error')

        expect(Rails.logger).to have_received(:error).with(
          'Failure in Banners::UpdateAllJob#sidekiq_retries_exhausted',
          {
            messaged_content: 'Logging error',
            job_id: '123',
            pre_exhaustion_failure: {
              error_class: 'SomeError',
              error_message: 'Something went wrong'
            }
          }
        )
      end
    end
  end
end
