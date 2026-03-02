# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CAVE API', type: :request do
  subject(:parsed_response) { JSON.parse(response.body) }

  let(:client) { instance_double(Idp::Client) }
  let(:user) { create(:user, :loa3) }

  before do
    Flipper.enable(:cave_idp)
    allow(Flipper).to receive(:enabled?).and_call_original
    allow(Flipper).to receive(:enabled?).with(:survivors_benefits_idp, instance_of(User)).and_return(true)
    allow(Idp).to receive(:client).and_return(client)
  end

  after { Flipper.disable(:cave_idp) }

  describe 'feature flags' do
    before { sign_in_as(user) }

    it 'returns 404 when cave_idp is disabled' do
      Flipper.disable(:cave_idp)

      post '/v0/cave', params: { pdf_b64: 'ZmlsZQ==', file_name: 'test.pdf' }

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 403 when survivors_benefits_idp is disabled for the user' do
      allow(Flipper).to receive(:enabled?).with(:survivors_benefits_idp, instance_of(User)).and_return(false)

      post '/v0/cave', params: { pdf_b64: 'ZmlsZQ==', file_name: 'test.pdf' }

      expect(response).to have_http_status(:forbidden)
      expect(parsed_response['errors'].first['detail']).to eq('IDP access is not enabled for this user')
    end
  end

  describe 'POST /v0/cave' do
    let(:params) { { pdf_b64: 'ZmlsZQ==', file_name: 'test.pdf' } }

    it 'returns 401 when unauthenticated' do
      post('/v0/cave', params:)

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 403 when survivors_benefits_idp is disabled' do
      sign_in_as(user)
      allow(Flipper).to receive(:enabled?).with(:survivors_benefits_idp, instance_of(User)).and_return(false)

      post('/v0/cave', params:)

      expect(response).to have_http_status(:forbidden)
    end

    it 'returns the upstream payload' do
      sign_in_as(user)
      allow(client).to receive(:intake).with(file_name: 'test.pdf', pdf_base64: 'ZmlsZQ==')
                                       .and_return('id' => 'abc123')

      post('/v0/cave', params:)

      expect(response).to have_http_status(:ok)
      expect(parsed_response['id']).to eq('abc123')
    end

    it 'returns bad gateway when upstream fails' do
      sign_in_as(user)
      allow(client).to receive(:intake).and_raise(Idp::Error, 'boom')

      post('/v0/cave', params:)

      expect(response).to have_http_status(:bad_gateway)
      expect(parsed_response['errors'].first['detail'])
        .to eq('Document processing service is temporarily unavailable')
    end

    it 'validates required params' do
      sign_in_as(user)

      post '/v0/cave', params: { pdf_b64: 'oops' }

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'GET /v0/cave/:id/status' do
    it 'returns 401 when unauthenticated' do
      get '/v0/cave/abc123/status'

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 403 when survivors_benefits_idp is disabled' do
      sign_in_as(user)
      allow(Flipper).to receive(:enabled?).with(:survivors_benefits_idp, instance_of(User)).and_return(false)

      get '/v0/cave/abc123/status'

      expect(response).to have_http_status(:forbidden)
    end

    it 'proxies the status call' do
      sign_in_as(user)
      allow(client).to receive(:status).with('abc123').and_return('scan_status' => 'completed')

      get '/v0/cave/abc123/status'

      expect(response).to have_http_status(:ok)
      expect(parsed_response['scan_status']).to eq('completed')
    end

    it 'returns bad gateway when upstream fails' do
      sign_in_as(user)
      allow(client).to receive(:status).with('abc123').and_raise(Idp::Error, 'boom')

      get '/v0/cave/abc123/status'

      expect(response).to have_http_status(:bad_gateway)
      expect(parsed_response['errors'].first['detail'])
        .to eq('Document processing service is temporarily unavailable')
    end
  end

  describe 'GET /v0/cave/:id/output' do
    it 'returns 401 when unauthenticated' do
      get '/v0/cave/abc123/output'

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 403 when survivors_benefits_idp is disabled' do
      sign_in_as(user)
      allow(Flipper).to receive(:enabled?).with(:survivors_benefits_idp, instance_of(User)).and_return(false)

      get '/v0/cave/abc123/output'

      expect(response).to have_http_status(:forbidden)
    end

    it 'defaults the type to artifact' do
      sign_in_as(user)
      allow(client).to receive(:output).with('abc123', type: 'artifact').and_return('forms' => [])

      get '/v0/cave/abc123/output'

      expect(response).to have_http_status(:ok)
    end

    it 'uses provided type' do
      sign_in_as(user)
      allow(client).to receive(:output).with('abc123', type: 'form').and_return('forms' => [])

      get '/v0/cave/abc123/output', params: { type: 'form' }

      expect(response).to have_http_status(:ok)
    end

    it 'returns bad gateway when upstream fails' do
      sign_in_as(user)
      allow(client).to receive(:output).with('abc123', type: 'artifact').and_raise(Idp::Error, 'boom')

      get '/v0/cave/abc123/output'

      expect(response).to have_http_status(:bad_gateway)
      expect(parsed_response['errors'].first['detail'])
        .to eq('Document processing service is temporarily unavailable')
    end
  end

  describe 'GET /v0/cave/:id/download' do
    it 'returns 401 when unauthenticated' do
      get '/v0/cave/abc123/download', params: { kvpid: 'kvp1' }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 403 when survivors_benefits_idp is disabled' do
      sign_in_as(user)
      allow(Flipper).to receive(:enabled?).with(:survivors_benefits_idp, instance_of(User)).and_return(false)

      get '/v0/cave/abc123/download', params: { kvpid: 'kvp1' }

      expect(response).to have_http_status(:forbidden)
    end

    it 'requires kvpid' do
      sign_in_as(user)

      get '/v0/cave/abc123/download'

      expect(response).to have_http_status(:bad_request)
    end

    it 'proxies the download call' do
      sign_in_as(user)
      allow(client).to receive(:download).with('abc123', kvpid: 'kvp1').and_return('data' => {})

      get '/v0/cave/abc123/download', params: { kvpid: 'kvp1' }

      expect(response).to have_http_status(:ok)
    end

    it 'returns bad gateway when upstream fails' do
      sign_in_as(user)
      allow(client).to receive(:download).with('abc123', kvpid: 'kvp1').and_raise(Idp::Error, 'boom')

      get '/v0/cave/abc123/download', params: { kvpid: 'kvp1' }

      expect(response).to have_http_status(:bad_gateway)
      expect(parsed_response['errors'].first['detail'])
        .to eq('Document processing service is temporarily unavailable')
    end
  end
end
