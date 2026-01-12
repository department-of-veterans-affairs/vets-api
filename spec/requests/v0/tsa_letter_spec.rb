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

    it 'returns the tsa letter metadata' do
      # params = {:pageRequest=>{:resultsPerPage=>10, :page=>1},
      #  :filters=>{"providerData.subject"=>{:evaluationType=>"CONTAINS", :value=>"[\"VETS Safe Travel Outreach Letter\"]"}},
      #  :sort=>[]}
      # mocked_response = Faraday::Response.new(response_body: tsa_letters, status: 200)
      # mocked_env = Faraday::Env.new(response: mocked_response).tap do |e|
      #   e.status = mocked_response.status
      #   e.body = mocked_response.body
      # end
      # expect_any_instance_of(Faraday::Connection).to receive(:post).with("folders/files:search", params).and_return(mocked_response)
      # allow(mocked_response).to receive(:env).and_return(mocked_env)

      VCR.use_cassette('tsa_letters/index_success', { match_requests_on: %i[method uri] }) do
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
