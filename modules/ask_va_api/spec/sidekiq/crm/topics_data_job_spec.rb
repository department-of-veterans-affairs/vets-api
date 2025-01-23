# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Crm::TopicsDataJob, type: :job do
  include ActiveJob::TestHelper

  describe '#perform' do
    let(:cache_data_instance) { instance_double(Crm::CacheData) }
    let(:logger) { instance_double(LogService) }

    before do
      allow(Crm::CacheData).to receive(:new).and_return(cache_data_instance)
      allow(cache_data_instance).to receive(:fetch_and_cache_data)
      allow(LogService).to receive(:new).and_return(logger)
      allow(logger).to receive(:call)
    end

    it 'creates an instance of Crm::CacheData and calls it' do
      described_class.new.perform

      expect(cache_data_instance).to have_received(:fetch_and_cache_data)
    end

    context 'when an error occurs' do
      let(:error_message) { 'Failed to update static data' }

      before do
        allow(cache_data_instance).to receive(:fetch_and_cache_data).and_raise(StandardError.new(error_message))
      end

      it 'logs the error' do
        expect { described_class.new.perform }.not_to raise_error

        expect(logger).to have_received(:call)
      end
    end
  end
end
