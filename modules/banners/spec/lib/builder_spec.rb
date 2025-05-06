# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Banners::Builder do
  let(:entity_id) { '123' }
  let(:banner_data) do
    {
      entity_id:,
      title: 'Test Banner',
      content: 'Test Content'
    }
  end

  let(:banner) { instance_double(Banner) }

  before do
    allow(Banner).to receive(:find_or_initialize_by).and_return(banner)
    allow(StatsD).to receive(:increment)
  end

  describe '.perform' do
    context 'when banner update succeeds' do
      before do
        allow(banner).to receive(:update).with(banner_data).and_return(true)
      end

      it 'returns the banner' do
        expect(described_class.perform(banner_data)).to eq(banner)
      end

      it 'logs success' do
        described_class.perform(banner_data)
        expect(StatsD).to have_received(:increment).with(
          'banners.builder.success',
          tags: ["entitiy_id:#{entity_id}"]
        )
      end
    end

    context 'when banner update fails' do
      before do
        allow(banner).to receive(:update).with(banner_data).and_return(false)
      end

      it 'returns false' do
        expect(described_class.perform(banner_data)).to be false
      end

      it 'logs failure' do
        described_class.perform(banner_data)
        expect(StatsD).to have_received(:increment).with(
          'banners.builder.failure',
          tags: ["entitiy_id:#{entity_id}"]
        )
      end
    end
  end

  describe '#banner' do
    let(:builder) { described_class.new(banner_data) }

    it 'finds or initializes banner by entity_id' do
      builder.banner
      expect(Banner).to have_received(:find_or_initialize_by).with(entity_id:)
    end

    it 'memoizes the banner' do
      expect(Banner).to receive(:find_or_initialize_by).once
      2.times { builder.banner }
    end
  end

  describe 'private class methods' do
    describe '#log_success' do
      it 'increments success metric with entity_id tag' do
        described_class.send(:log_success, entity_id)
        expect(StatsD).to have_received(:increment).with(
          'banners.builder.success',
          tags: ["entitiy_id:#{entity_id}"]
        )
      end
    end

    describe '#log_failure' do
      it 'increments failure metric with entity_id tag' do
        described_class.send(:log_failure, entity_id)
        expect(StatsD).to have_received(:increment).with(
          'banners.builder.failure',
          tags: ["entitiy_id:#{entity_id}"]
        )
      end
    end
  end
end
