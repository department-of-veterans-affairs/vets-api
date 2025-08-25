# frozen_string_literal: true

require 'rails_helper'

describe TravelPay::DocumentsService do
  let(:user) { build(:user) }
  let(:client) { instance_double(TravelPay::DocumentsClient) }
  let(:auth_manager) { instance_double(TravelPay::AuthManager) }
  let(:service) { described_class.new(auth_manager) }
  let(:doc_summary_data) do
    double(body: { 'data' => [{
             'documentId' => 'doc_id',
             'filename' => 'doc.pdf',
             'mimetype' => 'application/pdf',
             'createdon' => '2023-10-01T00:00:00Z'
           }] }, headers: {})
  end
  let(:doc_binary_data) do
    double(body: '{ "data": "binary_data"}',
           headers: {
             'Content-Disposition' => 'attachment; filename="doc.pdf"',
             'Content-Type' => 'application/pdf',
             'Content-Length' => 12_345
           })
  end
  let(:upload_response) { double(body: { 'data' => { 'documentId' => 'abc-123' } }) }

  before do
    allow_any_instance_of(TravelPay::DocumentsClient).to receive(:get_document_binary).and_return(doc_binary_data)
    allow(auth_manager).to receive_messages(authorize: { veis_token: 'veis_token',
                                                         btsss_token: 'btsss_token' })
  end

  describe '#get_document_summaries' do
    before do
      allow_any_instance_of(TravelPay::DocumentsClient).to receive(:get_document_ids).and_return(doc_summary_data)
    end

    it 'calls the client to get document IDs' do
      expect_any_instance_of(TravelPay::DocumentsClient).to receive(:get_document_ids).with('veis_token',
                                                                                            'btsss_token', 'claim_id')
      service.get_document_summaries('claim_id')
    end
  end

  describe '#download_document' do
    before do
      allow_any_instance_of(TravelPay::DocumentsClient).to receive(:get_document_binary).and_return(doc_binary_data)
    end

    it 'calls the client to get document binary' do
      params = { claim_id: 'claim_id', doc_id: 'doc_id' }
      expect_any_instance_of(TravelPay::DocumentsClient).to receive(:get_document_binary).with('veis_token',
                                                                                               'btsss_token', params)
      service.download_document(*params.values)
    end

    it 'sends the type and disposition headers of the original response' do
      params = { claim_id: 'claim_id', doc_id: 'doc_id' }
      allow(client).to receive(:get_document_binary).and_return(doc_binary_data)
      result = service.download_document(*params.values)
      expect(result[:disposition]).to include('filename="doc.pdf"')
      expect(result[:type]).to eq('application/pdf')
      expect(result[:content_length]).to eq(12_345)
    end

    it 'includes the filename in the returned hash' do
      params = { claim_id: 'claim_id', doc_id: 'doc_id' }
      allow(client).to receive(:get_document_binary).and_return(doc_binary_data)
      result = service.download_document(*params.values)
      expect(result[:filename]).to eq('doc.pdf')
    end

    describe '#upload_document' do  
      let(:claim_id) { 'claim-123' }
      let(:file_path) { 'modules/travel_pay/spec/fixtures/documents/test.pdf' }
      # Have to set the filename here since Rack::Test::UploadedFile creates a tempfile under /tmp with a unique name
      let(:file) { Rack::Test::UploadedFile.new(file_path, 'application/pdf', 'test.pdf') }

      before do
        allow_any_instance_of(TravelPay::DocumentsClient).to receive(:add_document).and_return(upload_response)
      end

      it 'calls the client to upload the document' do
        expect_any_instance_of(TravelPay::DocumentsClient).to receive(:add_document).with(
          'veis_token',
          'btsss_token',
          hash_including(claim_id:, document: file)
        )
        service.upload_document(claim_id, file)
      end

      it 'returns the data from the response body' do
        result = service.upload_document(claim_id, file)
        expect(result).to eq({ 'documentId' => 'abc-123' })
      end

      it 'raises ArgumentError when claim_id is missing' do
        expect { service.upload_document(nil, file) }.to raise_error(
          ArgumentError,
          /Missing Claim ID/
        )
      end

      it 'raises ArgumentError when document is missing' do
        expect { service.upload_document(claim_id, nil) }.to raise_error(
          ArgumentError,
          /Missing Claim ID or Uploaded Document/
        )
      end

      context 'when document type is invalid' do
        let(:invalid_file_path) { 'modules/travel_pay/spec/fixtures/documents/invalid.txt' }
        let(:invalid_file) { Rack::Test::UploadedFile.new(invalid_file_path, 'text/plain') }

        it 'raises a Common::Exceptions::BadRequest' do
          expect { service.upload_document(claim_id, invalid_file) }.to raise_error(
            Common::Exceptions::BadRequest
          )
        end
      end

      context 'when document size is invalid' do
        let(:oversized_pdf_file) do
          tf = Tempfile.new(['oversized', '.pdf'])
          tf.binmode # switches the Tempfile into binary mode
          # Minimal PDF header + repeat '0' to exceed 5 MB
          tf.write("%PDF-1.4\n#{'0' * ((5 * 1024 * 1024) + 1)}")
          tf.rewind # makes sure the uploaded file is actually readable as expected after writing to it.
          Rack::Test::UploadedFile.new(tf.path, 'application/pdf')
        end

        it 'raises a Common::Exceptions::BadRequest' do
          expect { service.upload_document(claim_id, oversized_pdf_file) }.to raise_error(
            Common::Exceptions::BadRequest
          )
        end
      end
    end
  end
end
