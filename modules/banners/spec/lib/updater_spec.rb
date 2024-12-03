# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Banners::Updater do
  let(:updater) { described_class.new }
  let(:banner_data) do
    [
      { 'entityId' => '1', 'title' => 'Test Banner 1', 'fieldBody' => { 'processed' => 'Test Banner 1 Content' } },
      { 'entityId' => '2', 'title' => 'Test Banner 2', 'fieldBody' => { 'processed' => 'Test Banner 2 Content' } }
    ]
  end

  describe '.perform' do
    it 'creates a new instance and calls update_vamc_banners' do
      instance = instance_double(described_class)
      expect(described_class).to receive(:new).and_return(instance)
      expect(instance).to receive(:update_vamc_banners)

      described_class.perform
    end
  end

  describe '#update_vamc_banners' do
    before do
      allow(updater).to receive(:vamcs_banner_data).and_return(banner_data)
      allow(Banners::Builder).to receive(:perform).and_return(true)
    end

    it 'returns true when all banners are successfully updated' do
      expect(updater).to receive(:destroy_missing_banners).with(%w[1 2])
      expect(updater).to receive(:log_success).with('vamc')

      expect(updater.update_vamc_banners).to be true
    end

    it 'returns false when banner update fails' do
      allow(Banners::Builder).to receive(:perform).and_return(false)
      expect(updater).to receive(:log_failure).with('vamc')

      expect(updater.update_vamc_banners).to be false
    end
  end

  describe '#vamcs_banner_data' do
    let(:mock_response) { double('response', body: response_body) }
    let(:mock_connection) { double('connection') }

    before do
      allow(updater).to receive(:connection).and_return(mock_connection)
      allow(mock_connection).to receive(:post).and_return(mock_response)
    end

    context 'when response is valid JSON' do
      let(:response_body) do
        {
          data: {
            nodeQuery: {
              entities: banner_data
            }
          }
        }.to_json
      end

      it 'returns parsed banner data' do
        expect(updater.send(:vamcs_banner_data)).to eq(banner_data)
      end
    end

    context 'when response is invalid JSON' do
      let(:response_body) { 'invalid json' }

      it 'returns an error' do
        expect { updater.send(:vamcs_banner_data) }.to raise_error(Banners::Updater::BannerDataFetchError)
      end
    end
  end

  describe '#log_success' do
    it 'increments StatsD with success metric' do
      expect(StatsD).to receive(:increment).with(
        'banners.updater.success',
        tags: ['banner_type:test']
      )

      updater.send(:log_success, 'test')
    end
  end

  describe '#log_failure' do
    it 'increments StatsD with failure metric' do
      expect(StatsD).to receive(:increment).with(
        'banners.updater.failure',
        tags: ['banner_type:test']
      )

      updater.send(:log_failure, 'test')
    end
  end
end
