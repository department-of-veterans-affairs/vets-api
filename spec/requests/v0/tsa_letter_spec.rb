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
      VCR.use_cassette('tsa_letters/index_success', { match_requests_on: %i[method uri] }) do
        get '/v0/tsa_letter'
        expect(response.body).to eq({uuid: 'c75438b4-47f8-44d3-9e35-798158591456', version: '920debba-cc65-479c-ab47-db9b2a5cd95f'}.to_json)
      end
    end

    it 'renders error message' do
      VCR.use_cassette('tsa_letters/index_not_found', { match_requests_on: %i[method uri] }) do
        get '/v0/tsa_letter'
        expect(response.body).to eq({uuid: 'c75438b4-47f8-44d3-9e35-798158591456', version: '920debba-cc65-479c-ab47-db9b2a5cd95f'}.to_json)
      end
    end
  end

  describe 'GET /v0/tsa_letter/:id' do
    let(:document_id) { '{93631483-E9F9-44AA-BB55-3552376400D8}' }
    let(:content) { File.read('spec/fixtures/files/error_message.txt') }

    before do
      expect(efolder_service).to receive(:get_tsa_letter).with(document_id).and_return(content)
    end

    it 'sends the doc pdf' do
      get "/v0/tsa_letter/#{CGI.escape(document_id)}"
      expect(response.body).to eq(content)
    end
  end
end
