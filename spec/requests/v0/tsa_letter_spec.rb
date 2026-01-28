# frozen_string_literal: true

require 'rails_helper'

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

      it 'logs error and renders 422' do
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
          get '/v0/tsa_letter'
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.parsed_body.dig('errors', 0, 'detail'))
            .to eq('Invalid datetime format found in TSA letters data: 2025-09-09T14:18:53, null')
        end
      end
    end

    context 'when user is not loa3 or does not have an icn' do
      let(:user) { build(:user, :loa1, icn: nil) }

      it 'renders 403' do
        get '/v0/tsa_letter'
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET /v0/tsa_letter/:id/version/:version_id/download' do
    let(:document_id) { '93631483-E9F9-44AA-BB55-3552376400D8' }
    let(:version_id) { '920debba-cc65-479c-ab47-db9b2a5cd95f' }

    it 'renders 200 and sends the doc pdf' do
      VCR.use_cassette('tsa_letters/download_success', { match_requests_on: %i[method uri] }) do
        get "/v0/tsa_letter/#{document_id}/version/#{version_id}/download"
        expect(response).to have_http_status(:ok)
        expect(response.headers['Content-Type']).to eq('application/pdf')
        expect(response.headers['Content-Disposition']).to include('attachment')
        expect(response.headers['Content-Disposition']).to include('filename="VETS Safe Travel Outreach Letter.pdf"')
        expect(response.body).to eq('%PDF-1.4 fake pdf content for testing purposes')
      end
    end

    context 'when upstream returns error status' do
      let(:document_id) { 'nonexistent-uuid' }
      let(:version_id) { 'nonexistent-version' }

      it 'renders 503' do
        VCR.use_cassette('tsa_letters/download_not_found', { match_requests_on: %i[method uri] }) do
          get "/v0/tsa_letter/#{document_id}/version/#{version_id}/download"
          expect(response).to have_http_status(:service_unavailable)
        end
      end
    end

    context 'when user is not loa3 or does not have an icn' do
      let(:user) { build(:user, :loa1, icn: nil) }

      it 'renders 403' do
        get "/v0/tsa_letter/#{document_id}/version/#{version_id}/download"
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
