# frozen_string_literal: true

require 'rails_helper'
require 'claims_evidence_api/service/search'

RSpec.describe 'VO::TsaLetter', type: :request do
  let(:user) { build(:user, :loa3) }

  before do
    sign_in_as(user)
  end

  describe 'GET /v0/tsa_letter' do
    it 'renders the most recent tsa letter metadata' do
      VCR.use_cassette('tsa_letters/show_success', { match_requests_on: %i[method uri body] }) do
        get '/v0/tsa_letter'
        expect(response).to have_http_status(:ok)
        expect(response.body).to eq({ data: { id: '', type: 'tsa_letter',
                                              attributes: {
                                                document_id: 'c75438b4-47f8-44d3-9e35-798158591456',
                                                document_version: '920debba-cc65-479c-ab47-db9b2a5cd95f',
                                                modified_datetime: '2025-09-09T14:18:53'
                                              } } }.to_json)
      end
    end

    context 'when user has no letter' do
      it 'renders an empty response' do
        VCR.use_cassette('tsa_letters/show_success_empty', { match_requests_on: %i[method uri body] }) do
          get '/v0/tsa_letter'
          expect(response).to have_http_status(:ok)
          expect(response.body).to eq({ data: nil }.to_json)
        end
      end
    end

    context 'when upstream returns 403' do
      it 'renders 404' do
        VCR.use_cassette('tsa_letters/show_not_found', { match_requests_on: %i[method uri body] }) do
          get '/v0/tsa_letter'
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'when upstream renders other error' do
      it 'renders 503' do
        VCR.use_cassette('tsa_letters/show_error', { match_requests_on: %i[method uri body] }) do
          get '/v0/tsa_letter'
          expect(response).to have_http_status(:service_unavailable)
        end
      end
    end

    context 'when response contains invalid datetime' do
      let(:bad_response) do
        {
          'files' => [
            {
              'uuid' => 'c75438b4-47f8-44d3-9e35-798158591456',
              'currentVersionUuid' => '920debba-cc65-479c-ab47-db9b2a5cd95f',
              'currentVersion' => {
                'providerData' => {
                  'modifiedDateTime' => '2025-09-09T14:18:53'
                }
              }
            },
            {
              'uuid' => 'c75438b4-47f8-44d3-9e35-798158591456',
              'currentVersionUuid' => 'cbb29e79-a10d-4757-b266-3db336fcffbe',
              'currentVersion' => {
                'providerData' => {
                  'modifiedDateTime' => 'null'
                }
              }
            }
          ]
        }
      end

      it 'logs error and renders 503' do
        VCR.use_cassette('tsa_letters/show_error', { match_requests_on: %i[method uri body] }) do
          # mocking this because I don't know if it's a real possibility
          mocked_response = Faraday::Response.new(response_body: bad_response, status: 200)
          mocked_env = Faraday::Env.new(response: mocked_response).tap do |e|
            e.status = mocked_response.status
            e.body = mocked_response.body
          end
          allow_any_instance_of(Faraday::Connection).to receive(:post).with('folders/files:search',
                                                                            any_args).and_return(mocked_response)
          allow(mocked_response).to receive(:env).and_return(mocked_env)
          allow(Rails.logger).to receive(:error) # this is the initial parsing error
          expect(Rails.logger).to receive(:error).with('Invalid datetime format found in TSA letters data',
                                                       ['2025-09-09T14:18:53', 'null'])
          get '/v0/tsa_letter'
          expect(response).to have_http_status(:internal_server_error)
        end
      end
    end
  end

  describe 'GET /v0/tsa_letter/:id' do
    let(:document_id) { '{93631483-E9F9-44AA-BB55-3552376400D8}' }
    let(:content) { File.read('spec/fixtures/files/error_message.txt') }

    it 'sends the doc pdf' do
      skip 'Pending migration to Claims Evidence API'
      get "/v0/tsa_letter/#{CGI.escape(document_id)}"
      expect(response.body).to eq(content)
    end
  end
end
