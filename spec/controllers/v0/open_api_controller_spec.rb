# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::OpenApiController, type: :controller do
  describe '#index' do
    let(:openapi_file_path) { Rails.root.join('config', 'openapi', 'openapi.json') }

    context 'when in production environment' do
      before do
        allow(Settings).to receive(:vsp_environment).and_return('production')
      end

      it 'returns a 404 status' do
        get :index
        expect(response).to have_http_status(:not_found)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['error']).to eq('OpenAPI specification is not available in production')
      end
    end

    context 'when OpenAPI file exists' do
      it 'returns a successful response' do
        get :index
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq('application/vnd.oai.openapi+json; charset=utf-8')
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
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(openapi_file_path).and_return(true)
        allow(File).to receive(:read).with(openapi_file_path).and_return('invalid json content')
        allow(File).to receive(:mtime).with(openapi_file_path).and_return(Time.current)
      end

      it 'returns a 404 status and logs the error' do
        expect(Rails.logger).to receive(:error).with(/Invalid openapi.json/)
        get :index
        expect(response).to have_http_status(:not_found)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['error']).to eq('OpenAPI specification not found')
      end
    end

    context 'caching and mtime behavior' do
      let(:valid_json) { { 'openapi' => '3.0.3' }.to_json }
      let(:initial_time) { Time.zone.parse('2025-01-01 12:00:00') }
      let(:later_time) { Time.zone.parse('2025-01-01 13:00:00') }

      before do
        # Clear Rails cache before each test
        Rails.cache.clear

        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(openapi_file_path).and_return(true)
      end

      it 'caches the parsed spec using mtime-based cache key' do
        allow(File).to receive(:mtime).with(openapi_file_path).and_return(initial_time)
        allow(File).to receive(:read).with(openapi_file_path).and_return(valid_json)

        # Verify Rails.cache.fetch is called with mtime-based key
        cache_key = "openapi_spec_#{initial_time.to_i}"
        expect(Rails.cache).to receive(:fetch).with(cache_key).and_call_original

        get :index
        expect(response).to have_http_status(:ok)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['openapi']).to eq('3.0.3')
      end

      it 'reloads the spec when file mtime changes' do
        # First call with initial time
        allow(File).to receive(:mtime).with(openapi_file_path).and_return(initial_time)
        allow(File).to receive(:read).with(openapi_file_path).and_return(valid_json)
        get :index
        expect(response).to have_http_status(:ok)

        # File gets updated with new mtime - cache key changes
        updated_json = { 'openapi' => '3.0.3', 'updated' => true }.to_json
        allow(File).to receive(:mtime).with(openapi_file_path).and_return(later_time)
        allow(File).to receive(:read).with(openapi_file_path).and_return(updated_json)

        # Should reload because mtime changed (different cache key)
        get :index
        expect(response).to have_http_status(:ok)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['updated']).to be(true)
      end
    end
  end
end
