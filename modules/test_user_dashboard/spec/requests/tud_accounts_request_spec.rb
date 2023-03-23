# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Test User Dashboard', type: :request do
  let(:rsa_private) { OpenSSL::PKey::RSA.new 2048 }
  let(:rsa_public) { rsa_private.public_key }
  let(:pub_key) { Base64.encode64(rsa_public.to_der) }
  let(:token) { JWT.encode 'test', rsa_private, 'RS256' }
  let(:headers) { { 'JWT' => token, 'PK' => pub_key } }

  describe '#index' do
    context 'without any authentication headers' do
      it 'refuses the request' do
        get('/test_user_dashboard/tud_accounts')

        expect(response.status).to eq 403
        expect(response.content_type).to eq 'text/html'
      end
    end

    context 'with valid authentication headers' do
      it 'accepts the request and returns a response' do
        get('/test_user_dashboard/tud_accounts', params: '', headers:)

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq 'application/json; charset=utf-8'
      end
    end

    context 'with invalid authentication headers' do
      it 'returns a 403' do
        get('/test_user_dashboard/tud_accounts', params: '', headers: { 'JWT' => 'invalid', 'PK' => pub_key })

        expect(response.status).to eq 403
      end
    end
  end

  describe '#update' do
    let(:tud_account) { create(:tud_account, id: '123') }
    let(:notes) { 'Test note string goes here.' }

    it 'updates the tud account notes field' do
      allow(TestUserDashboard::TudAccount).to receive(:find).and_return(tud_account)
      put('/test_user_dashboard/tud_accounts/123', params: { notes: }, headers:)

      expect(response).to have_http_status(:ok)
      expect(tud_account.notes).to eq('Test note string goes here.')
    end
  end
end
