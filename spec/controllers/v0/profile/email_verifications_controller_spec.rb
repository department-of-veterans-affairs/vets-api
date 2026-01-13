# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Profile::EmailVerificationsController, type: :controller do
  let(:user) { create(:user, :loa3) }
  let(:service) { instance_double(EmailVerificationService) }

  before do
    allow(EmailVerificationService).to receive(:new).and_return(service)
    allow(controller).to receive(:enforce_rate_limit!)
    allow(controller).to receive(:increment_rate_limit!)
    allow(controller).to receive(:reset_rate_limit!)
  end

  describe 'GET #status' do
    context 'when verification is not needed' do
      before do
        sign_in_as(user)
        allow(controller).to receive(:needs_verification?).and_return(false)
      end

      it 'returns needs_verification: false' do
        get :status

        body = JSON.parse(response.body)
        expect(response).to have_http_status(:ok)
        expect(body['data']['attributes']['needs_verification']).to be(false)
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
        expect(JSON.parse(response.body)['errors']).to be_present
      end
    end
  end

  describe 'POST #create' do
    before do
      sign_in_as(user)
    end

    context 'when verification is needed and rate limit not exceeded' do
      before do
        allow(controller).to receive(:needs_verification?).and_return(true)
        allow(service).to receive(:initiate_verification)
      end

      it 'sends verification email and returns success' do
        post :create

        expect(response).to have_http_status(:created)
      end

      it 'increments rate limit after successful send' do
        post :create

        expect(controller).to have_received(:increment_rate_limit!).with(:email_verification)
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
      end
    end

    context 'when rate limit is exceeded' do
      before do
        allow(controller).to receive(:needs_verification?).and_return(true)
        allow(controller).to receive(:enforce_rate_limit!).and_raise(Common::Exceptions::TooManyRequests)
      end

      it 'returns rate limit error' do
        post :create
        expect(response).to have_http_status(:too_many_requests)
        expect(JSON.parse(response.body)['errors']).to be_present
      end
    end

    context 'when service raises BackendServiceException' do
      before do
        allow(controller).to receive(:needs_verification?).and_return(true)
        allow(service).to receive(:initiate_verification).and_raise(
          Common::Exceptions::BackendServiceException.new(nil, detail: 'Service error')
        )
      end

      it 'returns service unavailable error' do
        post :create

        expect(response).to have_http_status(:service_unavailable)
      end
    end

    context 'when service raises unexpected error' do
      before do
        allow(controller).to receive(:needs_verification?).and_return(true)
        allow(service).to receive(:initiate_verification).and_raise(StandardError.new('Unexpected error'))
      end

      it 'returns internal server error' do
        post :create

        body = JSON.parse(response.body)
        expect(response).to have_http_status(:internal_server_error)
        expect(body['errors'][0]['code']).to eq('INTERNAL_SERVER_ERROR')
      end
    end
  end

  describe 'GET #verify' do
    before do
      sign_in_as(user)
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

      it 'resets rate limit on successful verification' do
        get :verify, params: { token: }

        expect(controller).to have_received(:reset_rate_limit!).with(:email_verification)
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

      it 'returns service unavailable error' do
        get :verify, params: { token: }

        expect(response).to have_http_status(:service_unavailable)
      end
    end

    context 'when service raises unexpected error' do
      let(:token) { 'valid-token' }

      before do
        allow(service).to receive(:verify_email!).and_raise(StandardError.new('Unexpected error'))
      end

      it 'returns internal server error' do
        get :verify, params: { token: }

        body = JSON.parse(response.body)
        expect(response).to have_http_status(:internal_server_error)
        expect(body['errors'][0]['code']).to eq('INTERNAL_SERVER_ERROR')
      end
    end
  end
end
