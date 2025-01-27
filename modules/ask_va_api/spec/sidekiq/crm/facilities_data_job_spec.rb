# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Crm::FacilitiesDataJob, type: :job do
  include ActiveJob::TestHelper

  describe '#perform' do
    let(:cache_data_instance) { Crm::CacheData.new }
    let(:response) do
      File.read('modules/ask_va_api/config/locales/get_facilities_mock_data.json')
    end

    context 'when successful' do
      before do
        allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('token')
        allow_any_instance_of(Crm::Service).to receive(:call).and_return(response)
        allow(Crm::CacheData).to receive(:new).and_return(cache_data_instance)
        allow(cache_data_instance).to receive(:fetch_and_cache_data)
      end

      context 'when successful' do
        it 'creates an instance of Crm::CacheData and calls fetch_and_cache_data with correct parameters' do
          described_class.new.perform

          expect(cache_data_instance).to have_received(:fetch_and_cache_data).with(
            endpoint: 'Facilities',
            cache_key: 'Facilities',
            payload: {}
          )
        end
      end
    end

    context 'when an error occurs during caching' do
      let(:logger) { instance_double(LogService) }
      let(:body) do
        '{"Data":null'
      end
      let(:failure) { Faraday::Response.new(response_body: body, status: 400) }

      before do
        allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('token')
        allow_any_instance_of(Crm::Service).to receive(:call).and_return(failure)
        allow(LogService).to receive(:new).and_return(logger)
        allow(logger).to receive(:call)
      end

      it 'logs the error and continues processing when an error occurs' do
        described_class.new.perform

        expect(logger).to have_received(:call)
      end
    end
  end
end
