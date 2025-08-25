# frozen_string_literal: true

require 'rails_helper'

describe TravelPay::DocumentsClient do
  let(:user) { build(:user) }

  expected_log_prefix = 'travel_pay.documents.response_time'
  before do
    @stubs = Faraday::Adapter::Test::Stubs.new

    conn = Faraday.new do |c|
      c.adapter(:test, @stubs)
      c.response :json
      c.request :multipart # this allows multipart bodies
      c.response :raise_error
    end

    allow_any_instance_of(TravelPay::DocumentsClient).to receive(:connection).and_return(conn)
    allow(StatsD).to receive(:measure)
  end

  context '/claims/:id/documents' do
    # GET document IDs and info
    it 'returns an array of document info from the /claims/:id/documents endpoint' do
      claim_id = '3fa85f64-5717-4562-b3fc-2c963f66afa6'
      @stubs.get("api/v2/claims/#{claim_id}/documents") do
        [
          200,
          {},
          {
            'data' => [
              {
                'documentId' => 'uuid1',
                'filename' => 'DecisionLetter.pdf',
                'mimetype' => 'application/pdf',
                'createdon' => '2025-03-24T14:00:52.893Z'
              },
              {
                'documentId' => 'uuid2',
                'filename' => 'screenshot.jpg',
                'mimetype' => 'image/jpeg',
                'createdon' => '2025-03-24T14:00:52.893Z'
              }
            ]
          }
        ]
      end

      expected_ids = %w[uuid1 uuid2]
      expected_filenames = %w[DecisionLetter.pdf screenshot.jpg]

      client = TravelPay::DocumentsClient.new
      new_documents_response = client.get_document_ids('veis_token', 'btsss_token',
                                                       claim_id)
      document_ids = new_documents_response.body['data'].pluck('documentId')
      document_filenames = new_documents_response.body['data'].pluck('filename')

      expect(StatsD).to have_received(:measure)
        .with(expected_log_prefix,
              kind_of(Numeric),
              tags: ['travel_pay:get_document_ids'])
      expect(document_ids).to eq(expected_ids)
      expect(document_filenames).to eq(expected_filenames)
    end
  end

  describe '#get_document_binary' do
    # GET document binary
    it 'returns the binary data of a document from get_document_binary' do
      claim_id = '3fa85f64-5717-4562-b3fc-2c963f66afa6'
      doc_id = 'uuid1'
      response = { 'data' => 'binary data' }

      @stubs.get("api/v2/claims/#{claim_id}/documents/#{doc_id}") do
        [200, { 'Content-Type' => 'application/pdf' }, response.to_json]
      end

      client = TravelPay::DocumentsClient.new
      document_binary_response = client.get_document_binary('veis_token', 'btsss_token', { claim_id:, doc_id: })

      expect(StatsD).to have_received(:measure)
        .with(expected_log_prefix,
              kind_of(Numeric),
              tags: ['travel_pay:get_document_binary'])
      expect(document_binary_response.body).to eq(response.to_json)
    end

    it 'raises an error when the response is not successful' do
      claim_id = '3fa85f64-5717-4562-b3fc-2c963f66afa6'
      doc_id = 'uuid1'

      @stubs.get("api/v2/claims/#{claim_id}/documents/#{doc_id}") do
        [404, {}, { 'error' => 'Document not found' }.to_json]
      end

      client = TravelPay::DocumentsClient.new
      expect do
        client.get_document_binary('veis_token', 'btsss_token', { claim_id:, doc_id: })
      end.to raise_error(Faraday::ResourceNotFound)
    end
  end

  describe '#add_document' do
    let(:claim_id) { 'claim-123' }
    let(:file_path) { 'modules/travel_pay/spec/fixtures/documents/test.pdf' }
    # Have to set the filename here since Rack::Test::UploadedFile creates a tempfile under /tmp with a unique name
    let(:file) { Rack::Test::UploadedFile.new(file_path, 'application/pdf', 'test.pdf') }

    it 'sends a POST to the correct URL with headers and Document body' do
      # Build a Faraday Multipart::FilePart explicitly so we can check the file name
      file_part = Faraday::Multipart::FilePart.new(
        file_path,           # path to your fixture file
        'application/pdf',   # Content type
        'test.pdf'           # explicit filename
      )
      @stubs.post("api/v3/claims/#{claim_id}/documents/form-data") do |env|
        # Check headers
        expect(env.request_headers['Authorization']).to eq('Bearer veis_token')
        expect(env.request_headers['BTSSS-Access-Token']).to eq('btsss_token')
        expect(env.request_headers['X-Correlation-ID']).to be_present

        # Check the multipart body
        # Normalize keys to symbols
        body = env.body.is_a?(Hash) ? env.body.transform_keys(&:to_sym) : {}
        document = body[:Document]
        expect(document).to be_a(Faraday::Multipart::FilePart)
        expect(document.original_filename).to eq('test.pdf')
        expect(document.content_type).to eq('application/pdf')

        [
          201,
          { 'Content-Type' => 'application/json' },
          { data: { documentId: 'abc-123' } }.to_json
        ]
      end

      client = TravelPay::DocumentsClient.new
      response = client.add_document('veis_token', 'btsss_token', claim_id:, document: file_part)

      expect(StatsD).to have_received(:measure)
        .with(expected_log_prefix,
              kind_of(Numeric),
              tags: ['travel_pay:add_document'])
      expect(response.status).to eq(201)
      expect(response.body['data']['documentId']).to eq('abc-123')
    end

    it 'raises an internal server error when the response is not successful' do
      @stubs.post("api/v3/claims/#{claim_id}/documents/form-data") do |_env|
        [500, { 'Content-Type' => 'application/json' }, { error: 'Internal Server Error' }.to_json]
      end

      client = TravelPay::DocumentsClient.new
      expect {
        client.add_document('veis_token', 'btsss_token', claim_id:, document: file)
      }.to raise_error(Faraday::ServerError)
    end

    it 'raises an error when the server responds with 400 Bad Request' do
      @stubs.post("api/v3/claims/#{claim_id}/documents/form-data") do |_env|
        [
          400,
          { 'Content-Type' => 'application/json' },
          { message: 'Bad Request' }.to_json
        ]
      end

      client = TravelPay::DocumentsClient.new

      expect do
        client.add_document('veis_token', 'btsss_token', claim_id:, document: file)
      end.to raise_error(Faraday::ClientError) # Faraday raises ClientError for 4xx
    end

    it 'raises an error when the server responds with 403 Forbidden' do
      @stubs.post("api/v3/claims/#{claim_id}/documents/form-data") do |_env|
        [
          403,
          { 'Content-Type' => 'application/json' },
          { message: 'Forbidden' }.to_json
        ]
      end

      client = TravelPay::DocumentsClient.new

      expect do
        client.add_document('veis_token', 'btsss_token', claim_id:, document: file)
      end.to raise_error(Faraday::ClientError) # Faraday raises ClientError for 4xx responses
    end

    it 'raises an error when the server responds with 413 Content Too Large' do
      @stubs.post("api/v3/claims/#{claim_id}/documents/form-data") do |_env|
        [
          413,
          { 'Content-Type' => 'application/json' },
          { message: 'Content Too Large' }.to_json
        ]
      end

      client = TravelPay::DocumentsClient.new

      expect do
        client.add_document('veis_token', 'btsss_token', claim_id:, document: file)
      end.to raise_error(Faraday::ClientError) do |error|
        # Optional: check that the response body matches what the API returned
        expect(error.response[:status]).to eq(413)
        expect(JSON.parse(error.response[:body])['message']).to eq('Content Too Large')
      end
    end
  end
end
