# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Profile::EmailVerificationsController, type: :request do
  include SchemaMatchers

  let(:user) { create(:user, :loa3, email: 'user@example.com', uuid: SecureRandom.uuid) }
  let(:va_profile_email) { 'va_profile@example.com' }
  let(:headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }
  let(:redis) { Redis::Namespace.new(described_class::REDIS_NAMESPACE, redis: $redis) }

  before do
    sign_in_as(user)
    # Clear Redis between tests
    $redis.flushdb
    # Mock VA Profile email
    allow(user).to receive(:va_profile_email).and_return(va_profile_email)
  end

  describe 'Authentication' do
    context 'when user is not authenticated' do
      before { request.session = nil }

      it 'returns 401 unauthorized for GET /v0/profile/email_verifications/status' do
        get('/v0/profile/email_verifications/status', headers:)

        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns 401 unauthorized for POST /v0/profile/email_verifications' do
        post('/v0/profile/email_verifications', headers:)

        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns 401 unauthorized for GET /v0/profile/email_verifications/verify' do
        get('/v0/profile/email_verifications/verify', headers:)

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when user is not LOA3' do
      let(:loa1_user) { create(:user, :loa1, email: 'user@example.com') }

      before do
        request.session = nil
        sign_in_as(loa1_user)
      end

      it 'returns 403 forbidden' do
        get('/v0/profile/email_verifications/status', headers:)

        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body['errors'].first['detail']).to include('must be logged in')
      end
    end
  end

  describe 'GET /v0/profile/email_verifications/status' do
    context 'when email verification is needed' do
      before do
        allow(user).to receive(:email).and_return('user@example.com')
        allow(user).to receive(:va_profile_email).and_return('different@example.com')
      end

      it 'returns needs_verification: true' do
        get('/v0/profile/email_verifications/status', headers:)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq(
          'data' => {
            'type' => 'email_verification_status',
            'attributes' => {
              'needs_verification' => true
            }
          }
        )
      end
    end

    context 'when email verification is not needed' do
      before do
        allow(user).to receive(:email).and_return('same@example.com')
        allow(user).to receive(:va_profile_email).and_return('same@example.com')
      end

      it 'returns needs_verification: false' do
        get('/v0/profile/email_verifications/status', headers:)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq(
          'data' => {
            'type' => 'email_verification_status',
            'attributes' => {
              'needs_verification' => false
            }
          }
        )
      end
    end
  end

  describe 'POST /v0/profile/email_verifications' do
    let(:email_verification_service) { instance_double(EmailVerificationService) }

    before do
      allow(EmailVerificationService).to receive(:new).with(user).and_return(email_verification_service)
      # Mock user emails to indicate verification is needed
      allow(user).to receive(:email).and_return('user@example.com')
      allow(user).to receive(:va_profile_email).and_return('different@example.com')
    end

    context 'when verification is successful' do
      before do
        allow(email_verification_service).to receive(:initiate_verification).and_return('mock-token')
      end

      it 'initiates email verification and returns success' do
        post('/v0/profile/email_verifications', headers:)

        expect(response).to have_http_status(:created)
        expect(response.parsed_body).to eq(
          'data' => {
            'type' => 'email_verification',
            'attributes' => {
              'email_sent' => true,
              'template_type' => 'initial_verification'
            }
          }
        )
        expect(email_verification_service).to have_received(:initiate_verification).with('initial_verification')
      end

      it 'accepts custom template_type parameter' do
        post('/v0/profile/email_verifications',
             params: { template_type: 'annual_verification' },
             headers:)

        expect(response).to have_http_status(:created)
        expect(response.parsed_body['data']['attributes']['template_type']).to eq('annual_verification')
        expect(email_verification_service).to have_received(:initiate_verification).with('annual_verification')
      end
    end

    context 'when email is already verified' do
      before do
        # Mock user emails to be the same (no verification needed)
        allow(user).to receive(:email).and_return('same@example.com')
        allow(user).to receive(:va_profile_email).and_return('same@example.com')
      end

      it 'returns 422 with email already verified error' do
        post('/v0/profile/email_verifications', headers:)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body).to eq(
          'errors' => [
            {
              'title' => 'Email Already Verified',
              'detail' => 'Your email address is already verified.',
              'code' => 'EMAIL_ALREADY_VERIFIED',
              'status' => '422'
            }
          ]
        )
        expect(EmailVerificationService).not_to have_received(:new)
      end
    end

    context 'when service raises BackendServiceException' do
      before do
        allow(email_verification_service).to receive(:initiate_verification)
          .and_raise(Common::Exceptions::BackendServiceException.new('VA900', {}))
      end

      it 'returns 503 service unavailable' do
        post('/v0/profile/email_verifications', headers:)

        expect(response).to have_http_status(:service_unavailable)
        expect(response.parsed_body).to eq(
          'errors' => [
            {
              'title' => 'Service Unavailable',
              'detail' => 'Email verification service is temporarily unavailable. Please try again later.',
              'code' => 'SERVICE_UNAVAILABLE',
              'status' => '503'
            }
          ]
        )
      end
    end

    context 'when an unexpected error occurs' do
      before do
        allow(email_verification_service).to receive(:initiate_verification)
          .and_raise(StandardError.new('Unexpected error'))
      end

      it 'returns 500 internal server error' do
        post('/v0/profile/email_verifications', headers:)

        expect(response).to have_http_status(:internal_server_error)
        expect(response.parsed_body).to eq(
          'errors' => [
            {
              'title' => 'Internal Server Error',
              'detail' => 'An unexpected error occurred. Please try again later.',
              'code' => 'INTERNAL_SERVER_ERROR',
              'status' => '500'
            }
          ]
        )
      end
    end

    context 'rate limiting' do
      before do
        allow(email_verification_service).to receive(:initiate_verification).and_return('mock-token')
      end

      it 'allows first request' do
        post('/v0/profile/email_verifications', headers:)

        expect(response).to have_http_status(:created)
      end

      it 'blocks request when period rate limit is exceeded' do
        # Make first request (should succeed)
        post('/v0/profile/email_verifications', headers:)
        expect(response).to have_http_status(:created)

        # Make second request (should be rate limited)
        post('/v0/profile/email_verifications', headers:)

        expect(response).to have_http_status(:too_many_requests)
        expect(response.parsed_body['errors'].first['title']).to eq('Rate Limit Exceeded')
        expect(response.parsed_body['errors'].first['code']).to eq('RATE_LIMIT_EXCEEDED')
        expect(response.parsed_body['errors'].first['meta']['resend_limit_per_period']).to eq(1)
        expect(response.parsed_body['errors'].first['meta']['resend_period_minutes']).to eq(5)
      end

      it 'blocks request when daily rate limit is exceeded' do
        # Simulate 5 requests in different periods (max daily limit)
        5.times do |i|
          # Set Redis key directly to simulate different time periods
          redis.set("#{user.uuid}:daily", i)
          redis.expire("#{user.uuid}:daily", 24.hours.to_i)

          post('/v0/profile/email_verifications', headers:)
          expect(response).to have_http_status(:created)

          # Clear period key to allow next request
          redis.del("#{user.uuid}:period")
        end

        # 6th request should be rate limited
        post('/v0/profile/email_verifications', headers:)

        expect(response).to have_http_status(:too_many_requests)
        expect(response.parsed_body['errors'].first['meta']['daily_limit']).to eq(5)
      end

      it 'includes retry_after in rate limit response' do
        # Make first request
        post('/v0/profile/email_verifications', headers:)

        # Make second request (rate limited)
        post('/v0/profile/email_verifications', headers:)

        expect(response).to have_http_status(:too_many_requests)
        expect(response.parsed_body['errors'].first['meta']['retry_after']).to be > 0
      end

      it 'logs rate limit denial' do
        # Make first request
        post('/v0/profile/email_verifications', headers:)

        expect(Rails.logger).to receive(:warn).with(
          'Email verification rate limit exceeded',
          hash_including(user_uuid: user.uuid, endpoint: 'create')
        )

        # Make second request (rate limited)
        post '/v0/profile/email_verifications', headers:
      end

      it 'increments StatsD counter for rate limit exceeded' do
        # Make first request
        post('/v0/profile/email_verifications', headers:)

        expect(StatsD).to receive(:increment).with(
          'api.profile.email_verification.rate_limit_exceeded',
          tags: hash_including('user_uuid' => user.uuid, 'endpoint' => 'create')
        )

        # Make second request (rate limited)
        post '/v0/profile/email_verifications', headers:
      end
    end
  end

  describe 'GET /v0/profile/email_verifications/verify' do
    let(:email_verification_service) { instance_double(EmailVerificationService) }
    let(:token) { 'valid-jwt-token' }

    before do
      allow(EmailVerificationService).to receive(:new).with(user).and_return(email_verification_service)
    end

    context 'with valid token' do
      before do
        allow(email_verification_service).to receive(:verify_email!).with(token).and_return(true)
      end

      it 'verifies email successfully and resets rate limit' do
        # Set up rate limit state
        redis.set("#{user.uuid}:period", 1)
        redis.set("#{user.uuid}:daily", 3)

        get('/v0/profile/email_verifications/verify', params: { token: }, headers:)
        # Check that rate limit was reset
        expect(redis.get("#{user.uuid}:period")).to be_nil
        expect(redis.get("#{user.uuid}:daily")).to be_nil
      end
    end

    context 'with invalid token' do
      before do
        allow(email_verification_service).to receive(:verify_email!).with(token).and_return(false)
      end

      it 'returns 422 with invalid token error' do
        get('/v0/profile/email_verifications/verify', params: { token: }, headers:)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body).to eq(
          'errors' => [
            {
              'title' => 'Invalid Token',
              'detail' => 'The verification token is invalid or has expired. Please request a new verification email.',
              'code' => 'INVALID_TOKEN',
              'status' => '422'
            }
          ]
        )
      end
    end

    context 'without token parameter' do
      it 'returns 400 with missing token error' do
        get('/v0/profile/email_verifications/verify', headers:)
        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body).to eq(
          'errors' => [
            {
              'title' => 'Missing Token',
              'detail' => 'Verification token is required.',
              'code' => 'MISSING_TOKEN',
              'status' => '400'
            }
          ]
        )
      end
    end

    context 'with empty token parameter' do
      it 'returns 400 with missing token error' do
        get('/v0/profile/email_verifications/verify', params: { token: '' }, headers:)
        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body['errors'].first['code']).to eq('MISSING_TOKEN')
      end
    end

    context 'when service raises BackendServiceException' do
      before do
        allow(email_verification_service).to receive(:verify_email!)
          .and_raise(Common::Exceptions::BackendServiceException.new('VA900', {}))
      end

      it 'returns 503 service unavailable' do
        get('/v0/profile/email_verifications/verify', params: { token: }, headers:)
        expect(response).to have_http_status(:service_unavailable)
        expect(response.parsed_body).to eq(
          'errors' => [
            {
              'title' => 'Service Unavailable',
              'detail' => 'Email verification service is temporarily unavailable. Please try again later.',
              'code' => 'SERVICE_UNAVAILABLE',
              'status' => '503'
            }
          ]
        )
      end
    end

    context 'when an unexpected error occurs' do
      before do
        allow(email_verification_service).to receive(:verify_email!)
          .and_raise(StandardError.new('Unexpected error'))
      end

      it 'returns 500 internal server error' do
        get('/v0/profile/email_verifications/verify', params: { token: }, headers:)
        expect(response).to have_http_status(:internal_server_error)
        expect(response.parsed_body).to eq(
          'errors' => [
            {
              'title' => 'Internal Server Error',
              'detail' => 'An unexpected error occurred. Please try again later.',
              'code' => 'INTERNAL_SERVER_ERROR',
              'status' => '500'
            }
          ]
        )
      end
    end

    it 'logs verification attempts' do
      allow(email_verification_service).to receive(:verify_email!).with(token).and_return(true)

      expect(Rails.logger).to receive(:info).with(
        'Email verification successful',
        hash_including(user_uuid: user.uuid)
      )

      get '/v0/profile/email_verifications/verify', params: { token: }, headers:
    end
  end

  describe 'Rate limiting helper methods' do
    let(:controller) { described_class.new }
    let(:period_key) { "#{user.uuid}:period" }
    let(:daily_key) { "#{user.uuid}:daily" }

    before do
      allow(controller).to receive(:current_user).and_return(user)
    end

    describe '#time_until_next_allowed' do
      it 'returns formatted time for period TTL' do
        redis.setex(period_key, 120, 1) # 2 minutes left

        expect(controller.send(:time_until_next_allowed)).to eq('2 minutes')
      end

      it 'returns formatted time for daily TTL' do
        redis.setex(daily_key, 3661, 5) # ~1 hour left

        expect(controller.send(:time_until_next_allowed)).to eq('1 hour')
      end

      it 'returns seconds for short durations' do
        redis.setex(period_key, 45, 1)

        expect(controller.send(:time_until_next_allowed)).to eq('45 seconds')
      end

      it 'returns "0 seconds" when no limits are active' do
        expect(controller.send(:time_until_next_allowed)).to eq('0 seconds')
      end
    end

    describe '#format_time_duration' do
      it 'formats seconds correctly' do
        expect(controller.send(:format_time_duration, 1)).to eq('1 second')
        expect(controller.send(:format_time_duration, 30)).to eq('30 seconds')
      end

      it 'formats minutes correctly' do
        expect(controller.send(:format_time_duration, 60)).to eq('1 minute')
        expect(controller.send(:format_time_duration, 120)).to eq('2 minutes')
      end

      it 'formats hours correctly' do
        expect(controller.send(:format_time_duration, 3600)).to eq('1 hour')
        expect(controller.send(:format_time_duration, 7200)).to eq('2 hours')
      end
    end
  end
end
