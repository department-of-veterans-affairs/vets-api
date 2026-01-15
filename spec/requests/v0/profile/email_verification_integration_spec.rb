# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Email Verification API', type: :request do
  let(:user) { create(:user, :loa3, email: 'user@example.com') }
  let(:headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }

  before do
    sign_in_as(user)
    allow(user).to receive(:va_profile_email).and_return('va_profile@example.com')
  end

  describe 'Basic functionality' do
    it 'returns status for authenticated LOA3 user' do
      get('/v0/profile/email_verification/status', headers:)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['data']['type']).to eq('email_verification')
      expect(response.parsed_body['data']['attributes']).to have_key('needs_verification')
    end

    it 'creates verification request when needed' do
      # Mock user emails to indicate verification is needed
      allow(user).to receive(:email).and_return('user@example.com')
      allow(user).to receive(:va_profile_email).and_return('different@example.com')
      allow_any_instance_of(EmailVerificationService).to receive(:initiate_verification).and_return('token')

      post('/v0/profile/email_verification', headers:)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['data']['type']).to eq('email_verification')
      expect(response.parsed_body['data']['attributes']['email_sent']).to be true
    end

    it 'verifies email with valid token' do
      allow_any_instance_of(EmailVerificationService).to receive(:verify_email!).and_return(true)

      get('/v0/profile/email_verification/verify', params: { token: 'valid-token' }, headers:)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['data']['attributes']['verified']).to be true
    end
  end
end
