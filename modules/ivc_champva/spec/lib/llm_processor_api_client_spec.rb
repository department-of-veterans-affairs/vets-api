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

  describe '#headers' do
    it 'returns the correct headers with acting user' do
      result = subject.headers('the_uuid', 'the_user')

      expect(result['api-key']).to eq('test-api-key-12345')
      expect(result['transactionUUID']).to eq('the_uuid')
      expect(result['acting-user']).to eq('the_user')
    end

    it 'returns the correct headers with nil acting user' do
      result = subject.headers('the_uuid', nil)

      expect(result['api-key']).to eq('test-api-key-12345')
      expect(result['transactionUUID']).to eq('the_uuid')
      expect(result['acting-user']).to eq('')
    end
  end

  describe '#build_multipart_body' do
    it 'builds a multipart body with PDF file and user prompt' do
      fixture_path = Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'files', 'SampleEOB.pdf')
      body = subject.build_multipart_body(file_path: fixture_path.to_s, prompt: 'summarize this document')

      expect(body[:user_prompt]).to eq('summarize this document')
      expect(body[:file]).to be_a(Faraday::UploadIO)
      expect(body[:file].content_type).to eq('application/pdf')
    end
  end

  describe '#process_document' do
    let(:transaction_uuid) { '123e4567-e89b-12d3-a456-426614174000' }
    let(:acting_user) { 'tester' }
    let(:prompt) { 'summarize this document' }

    it 'POSTs to /files/ProcessFiles with multipart form and tracks success' do
      fixture_path = Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'files', 'SampleEOB.pdf')

      captured_request = nil
      response = instance_double(Faraday::Response, status: 200, body: '{"ok":true}')

      fake_connection = double('Faraday::Connection')
      allow(fake_connection).to receive(:post) do |path, &blk|
        expect(path).to eq('/files/ProcessFiles')
        req = Struct.new(:headers, :body).new({}, nil)
        blk.call(req)
        captured_request = req
        response
      end
      client = described_class.new
      monitor = instance_double(IvcChampva::Monitor)
      allow(client).to receive_messages(connection: fake_connection, monitor:)
      expect(monitor).to receive(:track_llm_processor_response).with(transaction_uuid, 200, '{"ok":true}')

      resp = client.process_document(transaction_uuid, acting_user, { file_path: fixture_path.to_s, prompt: })

      expect(resp).to eq(response)
      expect(captured_request.headers['api-key']).to eq('test-api-key-12345')
      expect(captured_request.headers['transactionUUID']).to eq(transaction_uuid)
      expect(captured_request.headers['acting-user']).to eq(acting_user)

      expect(captured_request.body[:user_prompt]).to eq(prompt)
      expect(captured_request.body[:file]).to be_a(Faraday::UploadIO)
      expect(captured_request.body[:file].content_type).to eq('application/pdf')
    end
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
