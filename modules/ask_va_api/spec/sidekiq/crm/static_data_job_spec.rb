# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Crm::StaticDataJob, type: :job do
  include ActiveJob::TestHelper

  describe '#perform' do
    let(:static_data_instance) { instance_double(Crm::StaticData) }

    before do
      allow(Crm::StaticData).to receive(:new).and_return(static_data_instance)
      allow(static_data_instance).to receive(:fetch_api_data)
    end

    it 'creates an instance of Crm::StaticData and calls it' do
      described_class.new.perform

      expect(Crm::StaticData).to have_received(:new)
      expect(static_data_instance).to have_received(:fetch_api_data)
    end

    context 'when an error occurs' do
      let(:error_message) { 'Failed to update static data' }

      before do
        allow(static_data_instance).to receive(:fetch_api_data).and_raise(StandardError.new(error_message))
        allow_any_instance_of(Sidekiq::Job).to receive(:logger).and_return(double('Logger').as_null_object)
      end

      it 'logs the error' do
        expect_any_instance_of(Sidekiq::Job).to receive(:logger).and_return(double('Logger', error: true))
        expect { described_class.new.perform }.not_to raise_error
      end
    end
  end
end
