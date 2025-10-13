# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::ServiceAccountApplicationController, type: :controller do
  controller do
    before_action :authenticate_service_account

    def service_account_auth
      head :ok
    end
  end

  before do
    routes.draw do
      get 'service_account_auth' => 'sign_in/service_account_application#service_account_auth'
    end
  end

  describe '#authenticate_service_account' do
    subject { get :service_account_auth }

    shared_context 'error response' do
      let(:expected_error_json) { { 'errors' => expected_error } }
      let(:log_context) { { errors: expected_error, access_token_authorization_header: access_token } }

      it 'renders Malformed Params error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns unauthorized status' do
        expect(subject).to have_http_status(:unauthorized)
      end

      it 'logs error to Rails logger' do
        expect(Rails.logger).to receive(:error).with(
          '[SignIn][ServiceAccountAuthentication] authentication error',
          hash_including(**log_context)
        )
        subject
      end
    end

    context 'when authorization header does not exist' do
      let(:access_token) { nil }
      let(:expected_error) { 'Service Account access token JWT is malformed' }

      it_behaves_like 'error response'
    end

    context 'when authorization header exists' do
      let(:authorization) { "Bearer #{access_token}" }
      let(:access_token) { 'some-access-token' }

      before do
        request.headers['Authorization'] = authorization
      end

      context 'and access_token is some arbitrary value' do
        let(:access_token) { 'some-arbitrary-access-token' }
        let(:expected_error) { 'Service Account access token JWT is malformed' }
        let(:expected_error_json) { { 'errors' => expected_error } }

        it_behaves_like 'error response'
      end

      context 'and access_token is an expired JWT' do
        let(:access_token_object) { create(:access_token, expiration_time:) }
        let(:access_token) { SignIn::AccessTokenJwtEncoder.new(access_token: access_token_object).perform }
        let(:expiration_time) { 1.day.ago }
        let(:expected_error) { 'Service Account access token has expired' }
        let(:expected_error_json) { { 'errors' => expected_error } }

        it 'renders Access Token Expired error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns forbidden status' do
          expect(subject).to have_http_status(:forbidden)
        end
      end

      context 'and access_token is an active JWT' do
        let(:service_account_access_token) { create(:service_account_access_token, scopes: [scope]) }
        let(:access_token) do
          SignIn::ServiceAccountAccessTokenJwtEncoder.new(service_account_access_token:).perform
        end

        context 'and scope does not match request url' do
          let(:scope) { 'some-scope' }
          let(:expected_error) { 'Required scope for requested resource not found' }
          let(:expected_error_json) { { 'errors' => expected_error } }

          it_behaves_like 'error response'
        end

        context 'and scope matches request url' do
          let(:scope) { 'http://www.example.com/service_account_auth' }

          it 'returns ok status' do
            expect(subject).to have_http_status(:ok)
          end
        end
      end
    end
  end
end
