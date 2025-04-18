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
      c.request :json
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
end
