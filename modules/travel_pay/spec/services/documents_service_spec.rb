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
    double(body: { 'data' => 'binary_data' },
           headers: {
             'Content-Disposition' => 'attachment; filename="doc.pdf"',
             'Content-Type' => 'application/pdf',
             'Content-Length' => 12_345
           })
  end

  before do
    allow_any_instance_of(TravelPay::DocumentsClient).to receive(:get_document_ids).and_return(doc_summary_data)
    allow_any_instance_of(TravelPay::DocumentsClient).to receive(:get_document_binary).and_return(doc_binary_data)
    allow(auth_manager).to receive_messages(authorize: { veis_token: 'veis_token',
                                                         btsss_token: 'btsss_token' })
  end

  describe '#get_document_summaries' do
    it 'calls the client to get document IDs' do
      expect_any_instance_of(TravelPay::DocumentsClient).to receive(:get_document_ids).with('veis_token',
                                                                                            'btsss_token', 'claim_id')
      service.get_document_summaries('claim_id')
    end
  end

  describe '#download_document' do
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
  end
end
