# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../support/authentication'

RSpec.describe 'AccreditedRepresentativePortal::V0::Form21a', type: :request do
  let(:valid_json) { { field: 'value' }.to_json }
  let(:invalid_json) { 'invalid json' }
  let(:representative_user) { create(:representative_user) }

  before do
    Flipper.enable(:accredited_representative_portal_pilot)
    login_as(representative_user)
  end

  describe 'POST /accredited_representative_portal/v0/form21a' do
    context 'with valid JSON' do
      it 'returns a successful response from the service' do
        allow(AccreditationService).to receive(:submit_form21a).and_return(
          instance_double(Faraday::Response, success?: true, body: { result: 'success' }.to_json, status: 200)
        )

        headers = { 'Content-Type' => 'application/json' }
        post('/accredited_representative_portal/v0/form21a', params: valid_json, headers:)

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq('result' => 'success')
      end
    end

    context 'with invalid JSON' do
      it 'returns a bad request status' do
        headers = { 'Content-Type' => 'application/json' }
        post('/accredited_representative_portal/v0/form21a', params: invalid_json, headers:)

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)).to eq('errors' => 'Invalid JSON')
      end
    end

    context 'when service returns a blank response' do
      it 'returns no content status' do
        allow(AccreditationService).to receive(:submit_form21a).and_return(
          instance_double(Faraday::Response, success?: false, body: nil, status: 204)
        )

        headers = { 'Content-Type' => 'application/json' }
        post('/accredited_representative_portal/v0/form21a', params: valid_json, headers:)

        expect(response).to have_http_status(:no_content)
      end
    end

    context 'when service fails to parse response' do
      it 'returns a bad gateway status' do
        allow(AccreditationService).to receive(:submit_form21a).and_return(
          instance_double(Faraday::Response, success?: false, body: { errors: 'Failed to parse response' }.to_json,
                                             status: 502)
        )

        headers = { 'Content-Type' => 'application/json' }
        post('/accredited_representative_portal/v0/form21a', params: valid_json, headers:)

        expect(response).to have_http_status(:bad_gateway)
        expect(JSON.parse(response.body)).to eq('errors' => 'Failed to parse response')
      end
    end

    context 'when an unexpected error occurs' do
      it 'returns an internal server error status' do
        allow_any_instance_of(AccreditedRepresentativePortal::V0::Form21aController)
          .to receive(:parse_request_body).and_raise(StandardError, 'Unexpected error')

        post '/accredited_representative_portal/v0/form21a'

        expect(response).to have_http_status(:internal_server_error)
        expect(JSON.parse(response.body)).to match(
          'errors' => [
            {
              'title' => 'Internal server error',
              'detail' => 'Internal server error',
              'code' => '500',
              'status' => '500',
              'meta' => a_hash_including(
                'exception' => 'Unexpected error',
                'backtrace' => be_an(Array)
              )
            }
          ]
        )
      end
    end
  end
end
