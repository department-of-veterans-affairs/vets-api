# frozen_string_literal: true

require 'rails_helper'
require 'llm_processor_api/client'

RSpec.describe IvcChampva::LlmProcessorApi::Client do
  subject { described_class.new }

  before do
    # Mock the settings to avoid dependencies on actual configuration
    allow(Settings).to receive(:ivc_champva_llm_processor_api).and_return(
      OpenStruct.new(
        host: 'https://test-llm-api.example.com',
        api_key: 'test-api-key-12345'
      )
    )
  end

  describe 'configuration resolution' do
    describe 'configuration class' do
      let(:config) { IvcChampva::LlmProcessorApi::Configuration.instance }

      it 'resolves api_key from settings' do
        expect(config.api_key).to eq('test-api-key-12345')
      end

      it 'resolves base_path from settings' do
        expect(config.base_path).to eq('https://test-llm-api.example.com')
      end

      it 'has correct service_name' do
        expect(config.service_name).to eq('LlmProcessorApi::Client')
      end
    end

    describe 'client settings access' do
      it 'can access settings through settings method' do
        expect(subject.settings.api_key).to eq('test-api-key-12345')
        expect(subject.settings.host).to eq('https://test-llm-api.example.com')
      end
    end
  end
end
