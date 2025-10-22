# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::OpenApiController, type: :controller do
  describe '#index' do
    let(:openapi_file_path) { Rails.public_path.join('openapi.json') }

    context 'when OpenAPI file exists' do
      it 'returns a successful response' do
        get :index
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq('application/json; charset=utf-8')
        expect(JSON.parse(response.body)['openapi']).to eq('3.0.3')
      end

      it 'parses the JSON file correctly' do
        get :index
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['openapi']).to eq('3.0.3')
        expect(parsed_response['info']['title']).to eq('VA.gov OpenAPI Docs')
        expect(parsed_response['paths']).to be_present
      end

      it 'dynamically injects the server URL from request' do
        get :index
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['servers']).to be_present
        expect(parsed_response['servers']).to be_an(Array)
        expect(parsed_response['servers'].first['url']).to eq(request.base_url)
        expect(parsed_response['servers'].first['url']).to match(%r{^https?://})
      end
    end

    context 'when OpenAPI file does not exist' do
      before do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(openapi_file_path).and_return(false)
      end

      it 'returns a 404 status' do
        get :index
        expect(response).to have_http_status(:not_found)
        expect(response.content_type).to eq('application/json; charset=utf-8')
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['error']).to eq('OpenAPI specification not found')
      end

      it 'does not require authentication even when file is missing' do
        get :index
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when OpenAPI file exists but contains invalid JSON' do
      before do
        allow(File).to receive(:read).with(openapi_file_path).and_return('invalid json content')
      end

      it 'returns a 500 status' do
        get :index
        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end
end
