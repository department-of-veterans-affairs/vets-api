# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Crm::TopicsDataJob, type: :job do
  include ActiveJob::TestHelper

  describe '#perform' do
    let(:static_data_instance) { instance_double(Crm::CacheData) }
    let(:logger) { instance_double(SemanticLogger::Logger) }

    before do
      allow(Crm::CacheData).to receive(:new).and_return(static_data_instance)
      allow(static_data_instance).to receive(:fetch_api_data)
      allow(SemanticLogger).to receive(:[]).and_return(logger)
      allow(logger).to receive(:error)
    end

    it 'creates an instance of Crm::CacheData and calls it' do
      described_class.new.perform

      expect(Crm::CacheData).to have_received(:new)
      expect(static_data_instance).to have_received(:fetch_api_data)
    end

    context 'when an error occurs' do
      let(:error_message) { 'Failed to update static data' }

      before do
        allow(static_data_instance).to receive(:fetch_api_data).and_raise(StandardError.new(error_message))
      end

      it 'logs the error' do
        expect { described_class.new.perform }.not_to raise_error

        expect(logger).to have_received(:error).with(include(error_message))
      end
    end
  end
end
