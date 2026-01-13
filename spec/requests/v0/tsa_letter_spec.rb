# frozen_string_literal: true

require 'rails_helper'
require 'claims_evidence_api/service/search'

RSpec.describe 'VO::TsaLetter', type: :request do
  let(:user) { build(:user, :loa3) }

  before do
    sign_in_as(user)
  end

  describe 'GET /v0/tsa_letter' do
    it 'returns the most recent tsa letter metadata' do
      VCR.use_cassette('tsa_letters/show_success', { match_requests_on: %i[method uri body] }) do
        get '/v0/tsa_letter'
        expect(response).to have_http_status(:ok)
        expect(response.body).to eq({ data: { id: '', type: 'tsa_letter',
                                              attributes: {
                                                document_id: 'c75438b4-47f8-44d3-9e35-798158591456',
                                                document_version: '920debba-cc65-479c-ab47-db9b2a5cd95f',
                                                upload_datetime: '2025-09-09T14:18:53'
                                              } } }.to_json)
      end
    end

    it 'returns an empty response' do
      VCR.use_cassette('tsa_letters/show_success_empty', { match_requests_on: %i[method uri body] }) do
        get '/v0/tsa_letter'
        expect(response).to have_http_status(:ok)
        expect(response.body).to eq({ data: nil }.to_json)
      end
    end

    context 'when upstream returns 404' do
      it 'returns 404' do
        VCR.use_cassette('tsa_letters/show_not_found', { match_requests_on: %i[method uri body] }) do
          get '/v0/tsa_letter'
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'when upstream returns other error' do
      it 'returns 503' do
        VCR.use_cassette('tsa_letters/show_error', { match_requests_on: %i[method uri body] }) do
          get '/v0/tsa_letter'
          expect(response).to have_http_status(:service_unavailable)
        end
      end
    end
  end

  describe 'GET /v0/tsa_letter/:id' do
    let(:document_id) { '{93631483-E9F9-44AA-BB55-3552376400D8}' }
    let(:content) { File.read('spec/fixtures/files/error_message.txt') }

    before do
      expect(efolder_service).to receive(:get_tsa_letter).with(document_id).and_return(content)
    end

    it 'sends the doc pdf', pending: 'route change' do
      get "/v0/tsa_letter/#{CGI.escape(document_id)}"
      expect(response.body).to eq(content)
    end
  end
end
