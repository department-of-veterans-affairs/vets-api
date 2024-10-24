# frozen_string_literal: true

require 'rails_helper'
require AskVAApi::Engine.root.join('spec', 'support', 'shared_contexts.rb')

RSpec.describe Crm::OptionsetDataJob, type: :job do
  include ActiveJob::TestHelper

  describe '#perform' do
    include_context 'shared data'

    let(:cache_data_instance) { instance_double(Crm::CacheData) }
    let(:option_keys) do
      %w[inquiryabout inquirysource inquirytype levelofauthentication suffix veteranrelationship
         dependentrelationship responsetype]
    end

    context 'when successful' do
      before do
        allow(Crm::CacheData).to receive(:new).and_return(cache_data_instance)
        allow(cache_data_instance).to receive(:fetch_and_cache_data).with(
          endpoint: 'optionset',
          cache_key: 'optionset',
          payload: {}
        ).and_return(optionset_cached_data)
      end

      it 'creates an instance of Crm::CacheData for each option and calls it' do
        described_class.new.perform

        expect(cache_data_instance).to have_received(:fetch_and_cache_data).with(
          endpoint: 'optionset',
          cache_key: 'optionset',
          payload: {}
        )

        expect(cache_data_instance).to have_received(:fetch_and_cache_data)
      end
    end

    context 'when an error occurs during caching' do
      let(:logger) { instance_double(LogService) }
      let(:body) do
        '{"Data":null,"Message":"Data Validation: Invalid OptionSet Name iris_branchofservic, valid' \
          ' values are iris_inquiryabout, iris_inquirysource, iris_inquirytype, iris_levelofauthentication,' \
          ' iris_suffix, iris_veteranrelationship, iris_branchofservice, iris_country, iris_province,' \
          ' iris_responsetype, iris_dependentrelationship, statuscode, iris_messagetype","ExceptionOccurred":' \
          'true,"ExceptionMessage":"Data Validation: Invalid OptionSet Name iris_branchofservic, valid' \
          ' values are iris_inquiryabout, iris_inquirysource, iris_inquirytype, iris_levelofauthentication,' \
          ' iris_suffix, iris_veteranrelationship, iris_branchofservice, iris_country, iris_province,' \
          ' iris_responsetype, iris_dependentrelationship, statuscode, iris_messagetype","MessageId":' \
          '"6dfa81bd-f04a-4f39-88c5-1422d88ed3ff"}'
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
