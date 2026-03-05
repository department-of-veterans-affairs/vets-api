# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CAVE API', type: :request do
  subject(:parsed_response) { JSON.parse(response.body) }

  let(:client) { instance_double(Idp::Client) }
  let(:user) { create(:user, :loa3) }
  let(:idp_user_id) { user.user_account_uuid || user.uuid }

  before do
    Flipper.enable(:cave_idp)
    allow(Flipper).to receive(:enabled?).and_call_original
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
  end

  describe 'POST /v0/cave' do
    let(:params) { { pdf_b64: 'ZmlsZQ==', file_name: 'test.pdf' } }

    it 'returns 401 when unauthenticated' do
      post('/v0/cave', params:)

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns the upstream payload' do
      sign_in_as(user)
      allow(client).to receive(:intake).with(file_name: 'test.pdf', pdf_base64: 'ZmlsZQ==', user_id: idp_user_id)
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

    it 'proxies the status call' do
      sign_in_as(user)
      allow(client).to receive(:status).with('abc123', user_id: idp_user_id).and_return('scan_status' => 'completed')

      get '/v0/cave/abc123/status'

      expect(response).to have_http_status(:ok)
      expect(parsed_response['scan_status']).to eq('completed')
    end

    it 'returns bad gateway when upstream fails' do
      sign_in_as(user)
      allow(client).to receive(:status).with('abc123', user_id: idp_user_id).and_raise(Idp::Error, 'boom')

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

    it 'defaults the type to artifact' do
      sign_in_as(user)
      allow(client).to receive(:output).with('abc123', type: 'artifact', user_id: idp_user_id).and_return('forms' => [])

      get '/v0/cave/abc123/output'

      expect(response).to have_http_status(:ok)
    end

    it 'uses provided type' do
      sign_in_as(user)
      allow(client).to receive(:output).with('abc123', type: 'form', user_id: idp_user_id).and_return('forms' => [])

      get '/v0/cave/abc123/output', params: { type: 'form' }

      expect(response).to have_http_status(:ok)
    end

    it 'returns bad gateway when upstream fails' do
      sign_in_as(user)
      allow(client).to receive(:output).with('abc123', type: 'artifact', user_id: idp_user_id).and_raise(Idp::Error, 'boom')

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

    it 'requires kvpid' do
      sign_in_as(user)

      get '/v0/cave/abc123/download'

      expect(response).to have_http_status(:bad_request)
    end

    it 'proxies the download call' do
      sign_in_as(user)
      allow(client).to receive(:download).with('abc123', kvpid: 'kvp1', user_id: idp_user_id).and_return('data' => {})

      get '/v0/cave/abc123/download', params: { kvpid: 'kvp1' }

      expect(response).to have_http_status(:ok)
    end

    it 'returns bad gateway when upstream fails' do
      sign_in_as(user)
      allow(client).to receive(:download).with('abc123', kvpid: 'kvp1', user_id: idp_user_id).and_raise(Idp::Error, 'boom')

      get '/v0/cave/abc123/download', params: { kvpid: 'kvp1' }

      expect(response).to have_http_status(:bad_gateway)
      expect(parsed_response['errors'].first['detail'])
        .to eq('Document processing service is temporarily unavailable')
    end
  end

  describe 'POST /v0/cave/:id/update' do
    let(:payload) { { 'FIRST_NAME' => 'Ada', 'LAST_NAME' => 'Lovelace' } }
    let(:json_headers) { { 'CONTENT_TYPE' => 'application/json' } }

    it 'returns 401 when unauthenticated' do
      post '/v0/cave/abc123/update?kvpid=kvp1', params: payload.to_json, headers: json_headers

      expect(response).to have_http_status(:unauthorized)
    end

    it 'requires kvpid' do
      sign_in_as(user)

      post '/v0/cave/abc123/update', params: payload.to_json, headers: json_headers

      expect(response).to have_http_status(:bad_request)
    end

    it 'requires a valid JSON object body' do
      sign_in_as(user)

      post '/v0/cave/abc123/update?kvpid=kvp1', params: '[]', headers: json_headers

      expect(response).to have_http_status(:bad_request)
    end

    it 'proxies the update call' do
      sign_in_as(user)
      allow(client).to receive(:update)
        .with('abc123', kvpid: 'kvp1', payload:, user_id: idp_user_id)
        .and_return(payload)

      post '/v0/cave/abc123/update?kvpid=kvp1', params: payload.to_json, headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(parsed_response).to eq(payload)
    end

    it 'returns bad gateway when upstream fails' do
      sign_in_as(user)
      allow(client).to receive(:update)
        .with('abc123', kvpid: 'kvp1', payload:, user_id: idp_user_id)
        .and_raise(Idp::Error, 'boom')

      post '/v0/cave/abc123/update?kvpid=kvp1', params: payload.to_json, headers: json_headers

      expect(response).to have_http_status(:bad_gateway)
      expect(parsed_response['errors'].first['detail'])
        .to eq('Document processing service is temporarily unavailable')
    end
  end

  describe 'POST /v0/cave/diff' do
    let(:json_headers) { { 'CONTENT_TYPE' => 'application/json' } }

    it 'returns 401 when unauthenticated' do
      post '/v0/cave/diff', params: { lhs: {}, rhs: {} }.to_json, headers: json_headers

      expect(response).to have_http_status(:unauthorized)
    end

    it 'requires a JSON object request body' do
      sign_in_as(user)

      post '/v0/cave/diff', params: '[]', headers: json_headers

      expect(response).to have_http_status(:bad_request)
    end

    it "requires both 'lhs' and 'rhs'" do
      sign_in_as(user)

      post '/v0/cave/diff', params: { lhs: {} }.to_json, headers: json_headers

      expect(response).to have_http_status(:bad_request)
    end

    it 'returns coarse and fine-grained differences' do
      sign_in_as(user)
      payload = {
        lhs: { first_name: 'jee', last_name: 'doe' },
        rhs: { first_name: 'john', last_name: 'doe' }
      }

      post '/v0/cave/diff', params: payload.to_json, headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(parsed_response).to eq(
        'is_different' => true,
        'diff' => [
          { 'first_name' => { 'lhs' => 'jee', 'rhs' => 'john', 'is_different' => true } }
        ]
      )
    end

    it 'returns no differences when payloads are equal' do
      sign_in_as(user)
      payload = {
        lhs: { first_name: 'john', last_name: 'doe' },
        rhs: { first_name: 'john', last_name: 'doe' }
      }

      post '/v0/cave/diff', params: payload.to_json, headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(parsed_response).to eq('is_different' => false, 'diff' => [])
    end
  end
end
