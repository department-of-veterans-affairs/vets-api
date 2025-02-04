# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Banners do
  describe '.build' do
    let(:banner_props) do
      {
        entity_id: '123',
        title: 'Test Banner',
        content: 'Test Content'
      }
    end

    let(:builder_result) { double('builder_result') }

    before do
      allow(Banners::Builder).to receive(:perform).and_return(builder_result)
    end

    it 'delegates to Builder.perform' do
      expect(described_class.build(banner_props)).to eq(builder_result)
    end

    it 'calls Builder.perform with the correct arguments' do
      described_class.build(banner_props)
      expect(Banners::Builder).to have_received(:perform).with(banner_props)
    end

    context 'when called with different parameters' do
      let(:other_props) do
        {
          entity_id: '456',
          title: 'Another Banner',
          content: 'More Content'
        }
      end

      it 'passes different parameters correctly' do
        described_class.build(other_props)
        expect(Banners::Builder).to have_received(:perform).with(other_props)
      end
    end
  end

  describe '.update_all' do
    let(:updater_result) { double('updater_result') }

    before do
      allow(Banners::Updater).to receive(:perform).and_return(updater_result)
    end

    it 'delegates to Updater.perform' do
      expect(described_class.update_all).to eq(updater_result)
    end

    it 'calls Updater.perform with no arguments' do
      described_class.update_all
      expect(Banners::Updater).to have_received(:perform)
    end
  end
end
