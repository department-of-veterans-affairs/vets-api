# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Email Verification HTTP API', type: :request do
  let(:user) { create(:user, :loa3, email: 'user@example.com') }
  let(:headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }

  describe 'access control' do
    context 'with LOA3 user' do
      before do
        sign_in_as(user)
        allow(user).to receive(:va_profile_email).and_return('va_profile@example.com')
      end

      it 'allows access to all endpoints' do
        expect { get('/v0/profile/email_verification/status', headers:) }.not_to raise_error
        expect { post('/v0/profile/email_verification', headers:) }.not_to raise_error
        expect { get('/v0/profile/email_verification/verify', headers:) }.not_to raise_error
      end
    end

    context 'with non-LOA3 user' do
      let(:loa1_user) { create(:user, :loa1, email: 'user@example.com') }

      before do
        sign_in_as(loa1_user)
      end

      it 'denies access to status endpoint' do
        get('/v0/profile/email_verification/status', headers:)

        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)['errors'][0]['detail']).to eq('You must be logged in to access this feature')
      end

      it 'denies access to create endpoint' do
        post('/v0/profile/email_verification', headers:)

        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)['errors'][0]['detail']).to eq('You must be logged in to access this feature')
      end

      it 'denies access to verify endpoint' do
        get('/v0/profile/email_verification/verify', headers:)

        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)['errors'][0]['detail']).to eq('You must be logged in to access this feature')
      end
    end

    context 'with no user signed in' do
      # Don't sign in any user - tests should be completely unauthenticated

      it 'denies access to status endpoint' do
        get('/v0/profile/email_verification/status', headers:)

        expect(response).to have_http_status(:unauthorized)
      end

      it 'denies access to create endpoint' do
        post('/v0/profile/email_verification', headers:)

        expect(response).to have_http_status(:unauthorized)
      end

      it 'denies access to verify endpoint' do
        get('/v0/profile/email_verification/verify', headers:)

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # Authenticated endpoint tests (with proper user context)
  context 'as LOA3 user' do
    before do
      sign_in_as(user)
      allow(user).to receive(:va_profile_email).and_return('va_profile@example.com')
    end

    describe 'GET /v0/profile/email_verification/status' do
      it 'returns JSON response' do
        get('/v0/profile/email_verification/status', headers:)

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('application/json')
      end

      it 'returns status with correct data structure for authenticated LOA3 user' do
        get('/v0/profile/email_verification/status', headers:)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['data']['type']).to eq('email_verification')
        expect(response.parsed_body['data']['attributes']).to have_key('needs_verification')
        expect(response.parsed_body['data']['id']).to be_present
      end
    end

    describe 'POST /v0/profile/email_verification' do
      before do
        allow_any_instance_of(EmailVerificationService).to receive(:initiate_verification)
        allow(user).to receive_messages(
          email: 'user@example.com',
          va_profile_email: 'different@example.com'
        )
      end

      it 'accepts JSON requests' do
        post('/v0/profile/email_verification', headers:)

        expect(response).to have_http_status(:created)
        expect(response.content_type).to include('application/json')
      end

      it 'creates verification request when needed with correct data structure' do
        allow_any_instance_of(EmailVerificationService).to receive(:initiate_verification).and_return('token')

        post('/v0/profile/email_verification', headers:)

        expect(response).to have_http_status(:created)
        expect(response.parsed_body['data']['type']).to eq('email_verification')
        expect(response.parsed_body['data']['attributes']['email_sent']).to be true
        expect(response.parsed_body['data']['attributes']['template_type']).to be_present
        expect(response.parsed_body['data']['id']).to be_present
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

      it 'verifies email with valid token and returns correct data structure' do
        get('/v0/profile/email_verification/verify', params: { token: 'valid-token' }, headers:)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['data']['type']).to eq('email_verification')
        expect(response.parsed_body['data']['attributes']['verified']).to be true
        expect(response.parsed_body['data']['attributes']['verified_at']).to be_present
        expect(response.parsed_body['data']['id']).to be_present
      end
    end
  end
end
