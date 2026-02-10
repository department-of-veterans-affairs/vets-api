# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin', type: :request do
  describe 'GET /v0/header_status' do
    context 'when not in production' do
      before do
        allow(Settings).to receive(:vsp_environment).and_return('staging')
      end

      it 'returns http success' do
        get '/v0/header_status'
        expect(response).to have_http_status(:success)
      end

      it 'returns json content type' do
        get '/v0/header_status'
        expect(response.content_type).to match(%r{application/json})
      end

      it 'includes expected header information' do
        get '/v0/header_status'
        json_response = JSON.parse(response.body)

        expect(json_response).to include(
          'X-Forwarded-Proto',
          'X-Forwarded-Scheme',
          'request.ssl?',
          'request.protocol'
        )
      end

      it 'includes ssl status' do
        get '/v0/header_status'
        json_response = JSON.parse(response.body)

        expect(json_response['request.ssl?']).to be_in([true, false])
      end

      it 'includes protocol information' do
        get '/v0/header_status'
        json_response = JSON.parse(response.body)

        expect(json_response['request.protocol']).to match(%r{https?://})
      end

      context 'with X-Forwarded-Proto header' do
        it 'returns the forwarded proto value' do
          get '/v0/header_status', headers: { 'X-Forwarded-Proto' => 'https' }
          json_response = JSON.parse(response.body)

          expect(json_response['X-Forwarded-Proto']).to eq('https')
        end
      end

      context 'with X-Forwarded-Scheme header' do
        it 'returns the forwarded scheme value' do
          get '/v0/header_status', headers: { 'X-Forwarded-Scheme' => 'https' }
          json_response = JSON.parse(response.body)

          expect(json_response['X-Forwarded-Scheme']).to eq('https')
        end
      end

      context 'with both forwarding headers' do
        it 'returns both header values' do
          get '/v0/header_status', headers: {
            'X-Forwarded-Proto' => 'https',
            'X-Forwarded-Scheme' => 'https'
          }
          json_response = JSON.parse(response.body)

          expect(json_response['X-Forwarded-Proto']).to eq('https')
          expect(json_response['X-Forwarded-Scheme']).to eq('https')
        end
      end

      context 'without forwarding headers' do
        it 'returns nil for forwarding headers' do
          get '/v0/header_status'
          json_response = JSON.parse(response.body)

          expect(json_response['X-Forwarded-Proto']).to be_nil
          expect(json_response['X-Forwarded-Scheme']).to be_nil
        end
      end
    end

    context 'when in production' do
      before do
        allow(Settings).to receive(:vsp_environment).and_return('production')
      end

      it 'does not route to the endpoint' do
        get '/v0/header_status'
        json_response = JSON.parse(response.body)
        expect(json_response).to eq({})
      end
    end
  end
end
