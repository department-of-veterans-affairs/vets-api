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

  describe '#destroy_missing_banners' do
    let!(:banner1) { create(:banner, entity_id: '1') }
    let!(:banner2) { create(:banner, entity_id: '2') }
    let!(:banner3) { create(:banner, entity_id: '3') }

    it 'destroys banners whose entity_ids are not in the keep list' do
      expect do
        updater.send(:destroy_missing_banners, %w[1 2])
      end.to change(Banner, :count).by(-1)

      expect(Banner.find_by(entity_id: '3')).to be_nil
      expect(Banner.find_by(entity_id: '1')).to be_present
      expect(Banner.find_by(entity_id: '2')).to be_present
    end

    it 'destroys all banners when keep list is empty' do
      expect do
        updater.send(:destroy_missing_banners, [])
      end.to change(Banner, :count).by(-3)

      expect(Banner.count).to eq(0)
    end

    it 'handles non-existent entity_ids gracefully' do
      expect do
        updater.send(:destroy_missing_banners, %w[1 999])
      end.to change(Banner, :count).by(-2)

      expect(Banner.find_by(entity_id: '1')).to be_present
      expect(Banner.where.not(entity_id: '1')).to be_empty
    end
  end

  describe '#connection' do
    before do
      allow(Settings).to receive_messages(
        banners: OpenStruct.new(
          drupal_url: 'https://test.va.gov/graphql',
          drupal_username: 'test',
          drupal_password: 'test'
        )
      )
    end

    it 'creates a Faraday connection with correct config' do
      connection = updater.send(:connection)

      expect(connection).to be_a(Faraday::Connection)
      expect(connection.url_prefix.to_s).to eq('https://test.va.gov/graphql')
    end
  end

  describe '#faraday_options' do
    let(:options) { updater.send(:faraday_options) }

    it 'returns correct SSL options' do
      expect(options[:ssl][:verify]).to be false
    end

    context 'in non-production' do
      it 'includes proxy settings' do
        expect(options[:proxy]).to include(
          uri: URI.parse('socks://localhost:2001')
        )
      end
    end
  end
end
