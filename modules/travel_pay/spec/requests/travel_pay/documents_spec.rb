# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelPay::V0::DocumentsController, type: :request do
  let(:claim_id) { 'claim-123' }
  let(:doc_id) { 'doc-456' }
  let(:user) { build(:user) }

  before do
    allow_any_instance_of(TravelPay::AuthManager).to receive(:authorize).and_return({ veis_token: 'veis_token',
                                                                                      btsss_token: 'btsss_token' })
    sign_in(user)
  end

  describe 'GET /travel_pay/v0/documents/:id' do
    headers = { 'Authorization' => 'Bearer vagov_token' }
    filename = 'test.pdf'

    context 'when the document is successfully retrieved' do
      it 'returns the document data with correct headers' do
        VCR.use_cassette('travel_pay/documents/success_pdf', match_requests_on: %i[method path]) do
          get(doc_path, params: { filename: }, headers:)

          expect(response).to have_http_status(:ok)
          expect(response.body).not_to be_empty
          expect(response.headers['Content-Type']).to eq('application/pdf')
          expect(response.headers['Content-Disposition']).to include("attachment; filename=\"#{filename}\"")
          expect(response.headers['Content-Length']).to be_present
        end
      end
    end

    context 'when the document is not found' do
      it 'returns a 404 error with a proper message' do
        VCR.use_cassette('travel_pay/documents/not_found', match_requests_on: %i[method path]) do
          get(doc_path('bad-id'), params: { filename: }, headers:)

          expect(response).to have_http_status(:not_found)
          json = JSON.parse(response.body)
          expect(json['error']).to eq('Document not found')
        end
      end
    end

    context 'when an unhandled error occurs' do
      it 'logs the error and raises exception' do
        VCR.use_cassette('travel_pay/documents/internal_error', match_requests_on: %i[method path]) do
          expect(Rails.logger).to receive(:error).with(/Error downloading document:/)

          get(doc_path('big-bad-error'), params: { filename: }, headers:)

          expect(response).to have_http_status(:internal_server_error)
        end
      end
    end
  end

  def doc_path(doc_id = nil)
    "/travel_pay/v0/claims/#{claim_id}/documents/#{doc_id || 'doc-456'}"
  end
end
