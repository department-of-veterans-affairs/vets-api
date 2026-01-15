# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Email Verification HTTP API', type: :request do
  let(:user) { create(:user, :loa3, email: 'user@example.com') }
  let(:headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }

  before do
    sign_in_as(user)
    allow(user).to receive(:va_profile_email).and_return('va_profile@example.com')
  end

  describe 'Authentication' do
    it 'requires authentication for all endpoints' do
      expect { get('/v0/profile/email_verification/status', headers:) }.not_to raise_error
      expect { post('/v0/profile/email_verification', headers:) }.not_to raise_error
      expect { get('/v0/profile/email_verification/verify', headers:) }.not_to raise_error
    end
  end

  describe 'GET /v0/profile/email_verification/status' do
    it 'returns JSON response' do
      get('/v0/profile/email_verification/status', headers:)

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'POST /v0/profile/email_verification' do
    before do
      allow_any_instance_of(EmailVerificationService).to receive(:initiate_verification)
      allow(user).to receive(:email).and_return('user@example.com')
      allow(user).to receive(:va_profile_email).and_return('different@example.com')
    end

    it 'accepts JSON requests' do
      post('/v0/profile/email_verification', headers:)

      expect(response).to have_http_status(:created)
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'GET /v0/profile/email_verification/verify' do
    before do
      allow_any_instance_of(EmailVerificationService).to receive(:verify_email!).and_return(true)
    end

    it 'accepts token parameter' do
      get('/v0/profile/email_verification/verify', params: { token: 'test-token' }, headers:)

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')
    end
  end
end
