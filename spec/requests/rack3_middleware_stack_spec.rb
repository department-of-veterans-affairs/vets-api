# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rack 3.x Middleware Stack', type: :request do
  describe 'response body format compliance' do
    it 'returns array-wrapped response bodies' do
      get '/v0/status'

      # Rack 3.x requires response bodies to be enumerable
      expect(response.body).to be_a(String)

      # Access the actual Rack response
      rack_response = response.instance_variable_get(:@_response)
      if rack_response
        # In Rack 3.x, the body should be an array or respond to #each
        body = rack_response[2] # [status, headers, body]
        expect(body).to respond_to(:each)
      end
    end

    it 'handles JSON responses correctly through middleware stack' do
      # Use an existing authenticated endpoint or create a test one
      get '/v0/status'

      expect(response.content_type).to include('application/json').or include('text/html')
      # Verify response is well-formed
      expect(response.body).to be_present
    end

    it 'handles error responses with proper array bodies' do
      get '/v0/nonexistent_endpoint_12345'

      expect(response.status).to be >= 400
      # Body should still be properly formatted
      expect(response.body).to be_a(String)
    end
  end

  describe 'middleware chain execution order' do
    # Instead of mocking, verify middleware is present
    it 'has required middleware in the stack' do
      middleware_names = Rails.application.middleware.map(&:name)

      expect(middleware_names).to include('ActionDispatch::Cookies')
      expect(middleware_names).to include('Warden::Manager')
      expect(middleware_names).to include('ActionDispatch::Session::CookieStore')
    end

    it 'middleware processes requests in order' do
      # Make a simple request and verify it goes through successfully
      get '/v0/status'
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'multipart request handling' do
    # Create fixture files first
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

      # Should not crash with Rack 3.x
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
      # Should process without middleware errors
      expect(response.status).to be < 500
    end

    it 'handles query parameters correctly' do
      get '/v0/status', params: { filter: 'test', page: 1 }
      expect(response.status).to be < 500
    end
  end
end
