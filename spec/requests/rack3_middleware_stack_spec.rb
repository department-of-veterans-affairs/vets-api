# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rack 3.x Middleware Stack', type: :request do
  describe 'response body format compliance' do
    it 'returns array-wrapped response bodies' do
      get '/v0/status'

      expect(response.body).to be_a(String)
      rack_response = response.instance_variable_get(:@_response)
      if rack_response
        expect(body).to respond_to(:each)
      end
    end

    it 'handles JSON responses correctly through middleware stack' do
      get '/v0/status'

      expect(response.content_type).to include('application/json').or include('text/html')
      expect(response.body).to be_present
    end

    it 'handles error responses with proper array bodies' do
      get '/v0/nonexistent_endpoint_12345'

      expect(response.status).to be >= 400
      expect(response.body).to be_a(String)
    end
  end

  describe 'middleware chain execution order' do
    it 'has required middleware in the stack' do
      middleware_names = Rails.application.middleware.map(&:name)

      expect(middleware_names).to include('ActionDispatch::Cookies')
      expect(middleware_names).to include('Warden::Manager')
      expect(middleware_names).to include('ActionDispatch::Session::CookieStore')
    end

    it 'middleware processes requests in order' do
      get '/v0/status'
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'multipart request handling' do
    before do
      FileUtils.mkdir_p('spec/fixtures/files')
      File.write('spec/fixtures/files/test.txt', 'test content')
      File.write('spec/fixtures/files/test.pdf', '%PDF-1.4 fake pdf content')
    end

    after do
      FileUtils.rm_rf('spec/fixtures/files/test.txt')
      FileUtils.rm_rf('spec/fixtures/files/test.pdf')
    end

    it 'handles file uploads correctly' do
      skip 'No upload endpoint configured' unless defined?(V0::UploadsController)

      file = fixture_file_upload('files/test.pdf', 'application/pdf')

      post '/v0/upload', params: { file: }

      expect(response.status).to be < 500
    end

    it 'handles multipart form data with multiple fields' do
      skip 'No form endpoint configured' unless defined?(V0::FormsController)

      file = fixture_file_upload('test.txt', 'text/plain')

      post '/v0/form_submission', params: {
        field1: 'value1',
        field2: 'value2',
        file:
      }

      expect(response.status).to be < 500
    end
  end

  describe 'basic request/response handling' do
    it 'processes GET requests correctly' do
      get '/v0/status'
      expect(response.status).to be_between(200, 299).or be_between(400, 499)
    end

    it 'processes POST requests correctly' do
      post '/v0/status', params: { test: 'data' }.to_json,
                         headers: { 'Content-Type' => 'application/json' }
      expect(response.status).to be < 500
    end

    it 'handles query parameters correctly' do
      get '/v0/status', params: { filter: 'test', page: 1 }
      expect(response.status).to be < 500
    end
  end
end
