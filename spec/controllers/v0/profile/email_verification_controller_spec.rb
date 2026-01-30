# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Profile::EmailVerificationController, type: :controller do
  let(:user) { create(:user, :loa3) }
  let(:service) { instance_double(EmailVerificationService) }

  before do
    allow(Flipper).to receive(:enabled?).with(:auth_exp_email_verification_enabled).and_return(true)
    allow(EmailVerificationService).to receive(:new).and_return(service)
    allow(controller).to receive_messages(
      increment_email_verification_rate_limit!: nil,
      reset_email_verification_rate_limit!: nil
    )
  end

  describe 'GET #status' do
    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:auth_exp_email_verification_enabled).and_return(false)
        sign_in_as(user)
      end

      it 'returns forbidden with feature not available message' do
        get :status

        expect(response).to have_http_status(:forbidden)
        body = JSON.parse(response.body)
        expect(body['errors']).to be_present
        expect(body['errors'][0]['detail']).to eq('This feature is not currently available')
      end
    end

    context 'when verification is not needed' do
      before do
        allow(Flipper).to receive(:enabled?).with(:auth_exp_email_verification_enabled).and_return(true)
        sign_in_as(user)
        allow(controller).to receive(:needs_verification?).and_return(false)
      end

      it 'returns needs_verification: false and status verified' do
        get :status

        body = JSON.parse(response.body)
        expect(response).to have_http_status(:ok)
        expect(body['data']['id']).to be_present
        expect(body['data']['type']).to eq('email_verification')
        expect(body['data']['attributes']).to be_a(Hash)
        expect(body['data']['attributes']).to include('needs_verification', 'status')
        expect(body['data']['attributes']['needs_verification']).to be(false)
        expect(body['data']['attributes']['status']).to eq('verified')
      end
    end

    context 'when user lacks LOA3' do
      let(:user) { create(:user, :loa1) }

      before do
        sign_in_as(user)
      end

      it 'returns forbidden' do
        get :status

        expect(response).to have_http_status(:forbidden)
        body = JSON.parse(response.body)
        expect(body['errors']).to be_present
        expect(body['errors'][0]['detail']).to eq('You must be logged in to access this feature')
      end
    end

    context 'when VA Profile email lookup fails' do
      before do
        allow(user).to receive(:email).and_return('user@example.com')
        allow(user).to receive(:va_profile_email).and_raise(StandardError.new('VA Profile down'))
        sign_in_as(user)
      end

      it 'returns service unavailable with a controlled error' do
        allow(controller).to receive(:verification_needed_or_render_va_profile_error) do
          controller.send(:render_va_profile_unavailable_error)
          nil
        end

        get :status

        expect(response).to have_http_status(:service_unavailable)
        body = JSON.parse(response.body)
        error = body['errors'].first

        expect(error['code']).to eq('EMAIL_VERIFICATION_VA_PROFILE_UNAVAILABLE')
        expect(error['title']).to eq('VA Profile Unavailable')
        expect(error['status']).to eq('503')
      end
    end
  end

  describe 'POST #create' do
    before do
      sign_in_as(user)
    end

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:auth_exp_email_verification_enabled).and_return(false)
      end

      it 'returns forbidden with feature not available message' do
        post :create

        expect(response).to have_http_status(:forbidden)
        body = JSON.parse(response.body)
        expect(body['errors']).to be_present
        expect(body['errors'][0]['detail']).to eq('This feature is not currently available')
      end
    end

    context 'when user lacks LOA3' do
      let(:user) { create(:user, :loa1) }

      it 'returns forbidden with correct error detail' do
        post :create

        expect(response).to have_http_status(:forbidden)
        body = JSON.parse(response.body)
        expect(body['errors']).to be_present
        expect(body['errors'][0]['detail']).to eq('You must be logged in to access this feature')
      end
    end

    context 'when verification is needed and rate limit not exceeded' do
      before do
        allow(controller).to receive_messages(
          needs_verification?: true,
          enforce_email_verification_rate_limit!: nil
        )
        allow(service).to receive(:initiate_verification)
      end

      it 'sends verification email and returns success' do
        post :create

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body['data']['id']).to be_present
        expect(body['data']['type']).to eq('email_verification')
        expect(body['data']['attributes']).to be_a(Hash)
        expect(body['data']['attributes']).to include('email_sent', 'template_type')
        expect(body['data']['attributes']['email_sent']).to be(true)
        expect(body['data']['attributes']['template_type']).to eq('initial_verification')
      end

      it 'increments rate limit after successful send' do
        post :create

        expect(controller).to have_received(:increment_email_verification_rate_limit!)
      end

      context 'with custom template type' do
        it 'uses provided template type' do
          post :create, params: { template_type: 'update_verification' }

          expect(service).to have_received(:initiate_verification).with('update_verification')
        end
      end
    end

    context 'when verification is not needed' do
      before do
        allow(controller).to receive(:needs_verification?).and_return(false)
      end

      it 'returns unprocessable entity error' do
        post :create

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body['errors']).to be_present
        expect(body['errors'][0]['title']).to eq('Email Already Verified')
        expect(body['errors'][0]['detail']).to eq('Your email address is already verified.')
        expect(body['errors'][0]['code']).to eq('EMAIL_ALREADY_VERIFIED')
        expect(body['errors'][0]['status']).to eq('422')
      end
    end

    context 'when VA Profile email lookup fails' do
      before do
        allow(user).to receive(:email).and_return('user@example.com')
        allow(user).to receive(:va_profile_email).and_raise(StandardError.new('VA Profile down'))
        allow(service).to receive(:initiate_verification)
      end

      it 'returns service unavailable with a controlled error' do
        allow(controller).to receive(:verification_needed_or_render_va_profile_error) do
          controller.send(:render_va_profile_unavailable_error)
          nil
        end

        post :create

        expect(response).to have_http_status(:service_unavailable)
        body = JSON.parse(response.body)
        error = body['errors'].first

        expect(error['code']).to eq('EMAIL_VERIFICATION_VA_PROFILE_UNAVAILABLE')
        expect(error['title']).to eq('VA Profile Unavailable')
        expect(error['status']).to eq('503')
      end

      it 'does not call the verification service' do
        allow(controller).to receive(:verification_needed_or_render_va_profile_error) do
          controller.send(:render_va_profile_unavailable_error)
          nil
        end

        post :create

        expect(service).not_to have_received(:initiate_verification)
      end
    end

    context 'when rate limit is exceeded without exception detail' do
      before do
        allow(controller).to receive_messages(
          needs_verification?: true,
          time_until_next_verification_allowed: 0
        )
        allow(controller).to receive(:enforce_email_verification_rate_limit!).and_raise(
          Common::Exceptions::TooManyRequests.new
        )
      end

      it 'returns rate limit error using build_verification_rate_limit_message' do
        post :create

        expect(response).to have_http_status(:too_many_requests)

        body = JSON.parse(response.body)
        expect(body['errors']).to be_present
        expect(body['errors'][0]['code']).to eq('EMAIL_VERIFICATION_RATE_LIMIT_EXCEEDED')
        expect(body['errors'][0]['title']).to eq('Email Verification Rate Limit Exceeded')
        expect(body['errors'][0]['detail']).to eq('Too many requests. Please wait before trying again.')
        expect(body['errors'][0]['status']).to eq('429')
        expect(response.headers['Retry-After']).to be_present
      end
    end

    context 'when rate limit is exceeded with detailed timing message' do
      before do
        allow(controller).to receive_messages(
          needs_verification?: true,
          time_until_next_verification_allowed: 272
        )
        allow(controller).to receive(:enforce_email_verification_rate_limit!).and_raise(
          Common::Exceptions::TooManyRequests.new
        )
      end

      it 'returns a detailed timing error message' do
        post :create

        expect(response).to have_http_status(:too_many_requests)

        body = JSON.parse(response.body)
        error = body['errors'].first

        expect(error['code']).to eq('EMAIL_VERIFICATION_RATE_LIMIT_EXCEEDED')
        expect(error['title']).to eq('Email Verification Rate Limit Exceeded')
        expect(error['detail']).to eq(
          'Verification email limit reached. Wait 5 minutes to try again.'
        )
        expect(error['status']).to eq('429')
        expect(error['meta']['retry_after_seconds']).to eq(272)
        expect(response.headers['Retry-After']).to eq('272')
      end
    end

    context 'when service raises BackendServiceException' do
      before do
        allow(controller).to receive(:needs_verification?).and_return(true)
        allow(controller).to receive(:enforce_email_verification_rate_limit!)
        allow(service).to receive(:initiate_verification).and_raise(
          Common::Exceptions::BackendServiceException.new(nil, detail: 'Service error')
        )
      end

      it 'returns email verification service unavailable error' do
        post :create

        body = JSON.parse(response.body)
        expect(response).to have_http_status(:service_unavailable)
        expect(body['errors'][0]['code']).to eq('EMAIL_VERIFICATION_SERVICE_UNAVAILABLE')
        expect(body['errors'][0]['title']).to eq('Email Verification Service Unavailable')
      end
    end

    context 'when service raises unexpected error' do
      before do
        allow(controller).to receive(:needs_verification?).and_return(true)
        allow(controller).to receive(:enforce_email_verification_rate_limit!)
        allow(service).to receive(:initiate_verification).and_raise(StandardError.new('Unexpected error'))
      end

      it 'returns email verification internal error' do
        post :create

        body = JSON.parse(response.body)
        expect(response).to have_http_status(:internal_server_error)
        expect(body['errors'][0]['code']).to eq('EMAIL_VERIFICATION_INTERNAL_ERROR')
        expect(body['errors'][0]['title']).to eq('Email Verification Error')
      end
    end
  end

  describe 'GET #verify' do
    before do
      sign_in_as(user)
    end

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:auth_exp_email_verification_enabled).and_return(false)
      end

      it 'returns forbidden with feature not available message' do
        get :verify, params: { token: 'some-token' }

        expect(response).to have_http_status(:forbidden)
        body = JSON.parse(response.body)
        expect(body['errors']).to be_present
        expect(body['errors'][0]['detail']).to eq('This feature is not currently available')
      end
    end

    context 'when user lacks LOA3' do
      let(:user) { create(:user, :loa1) }

      it 'returns forbidden with correct error detail' do
        get :verify, params: { token: 'some-token' }

        expect(response).to have_http_status(:forbidden)
        body = JSON.parse(response.body)
        expect(body['errors']).to be_present
        expect(body['errors'][0]['detail']).to eq('You must be logged in to access this feature')
      end
    end

    context 'with valid token' do
      let(:token) { 'valid-token' }

      before do
        allow(service).to receive(:verify_email!).with(token).and_return(true)
      end

      it 'verifies email and returns success' do
        get :verify, params: { token: }

        expect(response).to have_http_status(:ok)
      end

      it 'returns correct response shape' do
        get :verify, params: { token: }

        body = JSON.parse(response.body)
        expect(body.dig('data', 'attributes')).to be_a(Hash)
        expect(body.dig('data', 'attributes')).to include('verified', 'verified_at')
        expect(body.dig('data', 'type')).to eq('email_verification')
        expect(body.dig('data', 'id')).to be_present
        expect(body.dig('data', 'attributes', 'verified')).to be(true)
        expect(body.dig('data', 'attributes', 'verified_at')).to be_present
      end

      it 'resets rate limit on successful verification' do
        get :verify, params: { token: }

        expect(controller).to have_received(:reset_email_verification_rate_limit!)
      end
    end

    context 'with invalid token' do
      let(:token) { 'invalid-token' }

      before do
        allow(service).to receive(:verify_email!).with(token).and_return(false)
      end

      it 'returns unprocessable entity error' do
        get :verify, params: { token: }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with missing token' do
      it 'returns bad request error' do
        get :verify

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when service raises BackendServiceException' do
      let(:token) { 'valid-token' }

      before do
        allow(service).to receive(:verify_email!).and_raise(
          Common::Exceptions::BackendServiceException.new(nil, detail: 'Service error')
        )
      end

      it 'returns email verification service unavailable error' do
        get :verify, params: { token: }

        body = JSON.parse(response.body)
        expect(response).to have_http_status(:service_unavailable)
        expect(body['errors'][0]['code']).to eq('EMAIL_VERIFICATION_SERVICE_UNAVAILABLE')
        expect(body['errors'][0]['title']).to eq('Email Verification Service Unavailable')
      end
    end

    context 'when service raises unexpected error' do
      let(:token) { 'valid-token' }

      before do
        allow(service).to receive(:verify_email!).and_raise(StandardError.new('Unexpected error'))
      end

      it 'returns email verification internal error' do
        get :verify, params: { token: }

        body = JSON.parse(response.body)
        expect(response).to have_http_status(:internal_server_error)
        expect(body['errors'][0]['code']).to eq('EMAIL_VERIFICATION_INTERNAL_ERROR')
        expect(body['errors'][0]['title']).to eq('Email Verification Error')
      end
    end
  end
end
