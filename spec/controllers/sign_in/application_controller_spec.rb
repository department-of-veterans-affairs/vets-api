# frozen_string_literal: true

require 'rails_helper'
require 'rx/client'

RSpec.describe SignIn::ApplicationController, type: :controller do
  controller do
    skip_before_action :authenticate, only: %w[index_optional_auth service_account_auth]
    before_action :load_user, only: %(index_optional_auth)
    before_action :authenticate_service_account, only: %(service_account_auth)
    attr_reader :payload

    def index
      head :ok
    end

    def index_optional_auth
      head :ok
    end

    def client_connection_failed
      client = Rx::Client.new(session: { user_id: 123 })
      client.get_session
    end

    def append_info_to_payload(payload)
      super
      @payload = payload
    end

    def service_account_auth
      head :ok
    end
  end

  before do
    routes.draw do
      get 'client_connection_failed' => 'sign_in/application#client_connection_failed'
      get 'index' => 'sign_in/application#index'
      get 'index_optional_auth' => 'sign_in/application#index_optional_auth'
      get 'service_account_auth' => 'sign_in/application#service_account_auth'
    end
  end

  describe '#authentication' do
    subject { get :index }

    shared_context 'error response' do
      let(:expected_error) { 'Access token JWT is malformed' }
      let(:expected_error_json) { { 'errors' => expected_error } }
      let(:sentry_context) do
        { access_token_authorization_header: access_token, access_token_cookie: }.compact
      end
      let(:sentry_log_level) { :error }

      it 'renders Malformed Params error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns unauthorized status' do
        expect(subject).to have_http_status(:unauthorized)
      end

      it 'logs error to sentry' do
        expect_any_instance_of(SentryLogging).to receive(:log_message_to_sentry).with(expected_error,
                                                                                      sentry_log_level,
                                                                                      sentry_context)
        subject
      end
    end

    shared_context 'user fingerprint validation' do
      context 'user.fingerprint matches request IP' do
        it 'passes fingerprint validation and does not create a log' do
          expect_any_instance_of(SentryLogging).not_to receive(:log_message_to_sentry).with(:warn)
          expect(subject.request.remote_ip).to eq(user.fingerprint)
        end
      end

      context 'user.fingerprint does not match request IP' do
        let!(:user) { create(:user, :loa3, uuid: access_token_object.user_uuid) }
        let(:expected_error) { '[SignIn][Authentication] fingerprint mismatch' }
        let(:log_context) { { request_ip: request.remote_ip, fingerprint: user.fingerprint } }

        it 'fails fingerprint validation and creates a log' do
          expect(Rails.logger).to receive(:warn).with(expected_error, log_context)

          expect(subject.request.remote_ip).not_to eq(user.fingerprint)
        end

        it 'does not prevent authentication' do
          expect(subject).to have_http_status(:ok)
        end
      end
    end

    context 'when authorization header does not exist' do
      let(:access_token) { nil }

      context 'and access token cookie does not exist' do
        let(:access_token_cookie) { nil }

        it_behaves_like 'error response'
      end

      context 'and access token cookie exists' do
        let(:access_token_cookie) { 'some-access-token' }

        before do
          cookies[SignIn::Constants::Auth::ACCESS_TOKEN_COOKIE_NAME] = access_token_cookie
        end

        context 'and access_token is some arbitrary value' do
          let(:access_token_cookie) { 'some-arbitrary-access-token' }
          let(:expected_error) { 'Access token JWT is malformed' }
          let(:expected_error_json) { { 'errors' => expected_error } }

          it_behaves_like 'error response'
        end

        context 'and access_token is an expired JWT' do
          let(:access_token_object) { create(:access_token, expiration_time:) }
          let(:access_token_cookie) { SignIn::AccessTokenJwtEncoder.new(access_token: access_token_object).perform }
          let(:expiration_time) { Time.zone.now - 1.day }
          let(:expected_error) { 'Access token has expired' }
          let(:expected_error_json) { { 'errors' => expected_error } }

          it 'renders Access Token Expired error' do
            expect(JSON.parse(subject.body)).to eq(expected_error_json)
          end

          it 'returns forbidden status' do
            expect(subject).to have_http_status(:forbidden)
          end
        end

        context 'and access_token is an active JWT' do
          let(:access_token_object) { create(:access_token) }
          let(:access_token_cookie) { SignIn::AccessTokenJwtEncoder.new(access_token: access_token_object).perform }
          let(:expected_error) { SignIn::Errors::AccessTokenMalformedJWTError.to_s }
          let!(:user) do
            create(:user, :loa3, uuid: access_token_object.user_uuid, fingerprint: request.remote_ip)
          end
          let(:user_serializer) { SignIn::IntrospectSerializer.new(user) }
          let(:expected_introspect_response) { JSON.parse(user_serializer.to_json) }

          it_behaves_like 'user fingerprint validation'

          it 'returns ok status' do
            expect(subject).to have_http_status(:ok)
          end
        end
      end
    end

    context 'when authorization header exists' do
      let(:authorization) { "Bearer #{access_token}" }
      let(:access_token) { 'some-access-token' }
      let(:access_token_cookie) { nil }

      before do
        request.headers['Authorization'] = authorization
      end

      context 'and access_token is some arbitrary value' do
        let(:access_token) { 'some-arbitrary-access-token' }
        let(:expected_error) { 'Access token JWT is malformed' }
        let(:expected_error_json) { { 'errors' => expected_error } }

        it_behaves_like 'error response'
      end

      context 'and access_token is an expired JWT' do
        let(:access_token_object) { create(:access_token, expiration_time:) }
        let(:access_token) { SignIn::AccessTokenJwtEncoder.new(access_token: access_token_object).perform }
        let(:expiration_time) { Time.zone.now - 1.day }
        let(:expected_error) { 'Access token has expired' }
        let(:expected_error_json) { { 'errors' => expected_error } }

        it 'renders Access Token Expired error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns forbidden status' do
          expect(subject).to have_http_status(:forbidden)
        end
      end

      context 'and access_token is an active JWT' do
        let(:access_token_object) { create(:access_token) }
        let(:access_token) { SignIn::AccessTokenJwtEncoder.new(access_token: access_token_object).perform }
        let(:expected_error) { SignIn::Errors::AccessTokenMalformedJWTError.to_s }
        let!(:user) do
          create(:user, :loa3, uuid: access_token_object.user_uuid, fingerprint: request.remote_ip)
        end
        let(:user_serializer) { SignIn::IntrospectSerializer.new(user) }
        let(:expected_introspect_response) { JSON.parse(user_serializer.to_json) }

        it_behaves_like 'user fingerprint validation'

        it 'returns ok status' do
          expect(subject).to have_http_status(:ok)
        end
      end
    end
  end

  describe '#load_user' do
    subject { get :index_optional_auth }

    shared_context 'error response' do
      it 'returns ok status' do
        expect(subject).to have_http_status(:ok)
      end
    end

    shared_context 'user fingerprint validation' do
      context 'user.fingerprint matches request IP' do
        it 'passes fingerprint validation and does not create a log' do
          expect_any_instance_of(SentryLogging).not_to receive(:log_message_to_sentry).with(:warn)
          expect(subject.request.remote_ip).to eq(user.fingerprint)
        end
      end

      context 'user.fingerprint does not match request IP' do
        let!(:user) { create(:user, :loa3, uuid: access_token_object.user_uuid) }
        let(:expected_error) { '[SignIn][Authentication] fingerprint mismatch' }
        let(:log_context) { { request_ip: request.remote_ip, fingerprint: user.fingerprint } }

        it 'fails fingerprint validation and creates a log' do
          expect(Rails.logger).to receive(:warn).with(expected_error, log_context)
          expect(subject.request.remote_ip).not_to eq(user.fingerprint)
        end

        it 'does not prevent authentication' do
          expect(subject).to have_http_status(:ok)
        end
      end
    end

    context 'when authorization header does not exist' do
      let(:expected_error) { 'Access token JWT is malformed' }
      let(:access_token) { nil }

      context 'and access token cookie does not exist' do
        let(:access_token_cookie) { nil }

        it_behaves_like 'error response'
      end

      context 'and access token cookie exists' do
        let(:access_token_cookie) { 'some-access-token' }

        before do
          cookies[SignIn::Constants::Auth::ACCESS_TOKEN_COOKIE_NAME] = access_token_cookie
        end

        context 'and access_token is some arbitrary value' do
          let(:access_token_cookie) { 'some-arbitrary-access-token' }

          it_behaves_like 'error response'
        end

        context 'and access_token is an expired JWT' do
          let(:access_token_object) { create(:access_token, expiration_time:) }
          let(:access_token_cookie) { SignIn::AccessTokenJwtEncoder.new(access_token: access_token_object).perform }
          let(:expiration_time) { Time.zone.now - 1.day }
          let(:expected_error) { 'Access token has expired' }
          let(:expected_error_json) { { 'errors' => expected_error } }

          it 'renders Access Token Expired error' do
            expect(JSON.parse(subject.body)).to eq(expected_error_json)
          end

          it 'returns forbidden status' do
            expect(subject).to have_http_status(:forbidden)
          end
        end

        context 'and access_token is an active JWT' do
          let(:access_token_object) { create(:access_token) }
          let(:access_token_cookie) { SignIn::AccessTokenJwtEncoder.new(access_token: access_token_object).perform }
          let(:expected_error) { SignIn::Errors::AccessTokenMalformedJWTError.to_s }
          let!(:user) do
            create(:user, :loa3, uuid: access_token_object.user_uuid, fingerprint: request.remote_ip)
          end
          let(:user_serializer) { SignIn::IntrospectSerializer.new(user) }
          let(:expected_introspect_response) { JSON.parse(user_serializer.to_json) }

          it_behaves_like 'user fingerprint validation'

          it 'returns ok status' do
            expect(subject).to have_http_status(:ok)
          end

          it 'does not log a warning to sentry' do
            expect(Rails.logger).not_to receive(:debug)
            subject
          end
        end
      end
    end

    context 'when authorization header exists' do
      let(:authorization) { "Bearer #{access_token}" }
      let(:access_token) { 'some-access-token' }
      let(:access_token_cookie) { nil }
      let(:expected_error) { 'Access token JWT is malformed' }

      before do
        request.headers['Authorization'] = authorization
      end

      context 'and access_token is some arbitrary value' do
        let(:access_token) { 'some-arbitrary-access-token' }

        it_behaves_like 'error response'
      end

      context 'and access_token is an expired JWT' do
        let(:access_token_object) { create(:access_token, expiration_time:) }
        let(:access_token) { SignIn::AccessTokenJwtEncoder.new(access_token: access_token_object).perform }
        let(:expiration_time) { Time.zone.now - 1.day }
        let(:expected_error) { 'Access token has expired' }
        let(:expected_error_json) { { 'errors' => expected_error } }

        it 'renders Access Token Expired error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns forbidden status' do
          expect(subject).to have_http_status(:forbidden)
        end
      end

      context 'and access_token is an active JWT' do
        let(:access_token_object) { create(:access_token) }
        let(:access_token) { SignIn::AccessTokenJwtEncoder.new(access_token: access_token_object).perform }
        let(:expected_error) { SignIn::Errors::AccessTokenMalformedJWTError.to_s }
        let!(:user) do
          create(:user, :loa3, uuid: access_token_object.user_uuid, fingerprint: request.remote_ip)
        end
        let(:user_serializer) { SignIn::IntrospectSerializer.new(user) }
        let(:expected_introspect_response) { JSON.parse(user_serializer.to_json) }

        it_behaves_like 'user fingerprint validation'

        it 'returns ok status' do
          expect(subject).to have_http_status(:ok)
        end

        it 'does not log a warning to sentry' do
          expect(Rails.logger).not_to receive(:debug)
          subject
        end
      end
    end
  end

  describe 'instrumentation' do
    subject { get :index }

    context 'with a valid authenticated request' do
      let(:authorization) { "Bearer #{access_token}" }
      let(:access_token_object) { create(:access_token) }
      let(:access_token) { SignIn::AccessTokenJwtEncoder.new(access_token: access_token_object).perform }

      before do
        request.headers['Authorization'] = authorization
      end

      it 'appends user uuid to payload' do
        subject
        expect(controller.payload[:user_uuid]).to eq(access_token_object.user_uuid)
      end

      it 'appends session handle to payload' do
        subject
        expect(controller.payload[:session]).to eq(access_token_object.session_handle)
      end
    end
  end

  context 'when a failure occurs with the client connection' do
    subject { get :client_connection_failed }

    let(:authorization) { "Bearer #{access_token}" }
    let(:access_token_object) { create(:access_token, user_uuid: user_account.id, session_handle: session.handle) }
    let(:session) { create(:oauth_session, user_account:) }
    let(:access_token) { SignIn::AccessTokenJwtEncoder.new(access_token: access_token_object).perform }
    let(:user_account) { create(:user_account) }
    let(:va_exception_error) do
      {
        va_exception_errors: [{
          title: 'Service unavailable', detail: 'Backend Service Outage', code: '503', status: '503'
        }]
      }
    end
    let(:controller_name) { 'application' }
    let(:client_type) { 'mhv_session' }
    let(:sign_in_method) { SignIn::Constants::Auth::IDME }
    let(:authn_context) { LOA::IDME_LOA3 }
    let(:tags_context) { { controller_name:, sign_in_method:, sign_in_acct_type: nil } }
    let(:loa) { { current: 3, highest: 3 } }
    let(:user_context) do
      { id: access_token_object.user_uuid, authn_context:, loa:, mhv_icn: user_account.icn }
    end
    let!(:user) do
      create(:user, uuid: access_token_object.user_uuid,
                    loa:,
                    authn_context:,
                    mhv_icn: user_account.icn,
                    fingerprint: request.remote_ip)
    end
    let(:expected_error) { 'Service unavailable' }

    before do
      request.headers['Authorization'] = authorization
      allow_any_instance_of(Rx::Client).to receive(:connection).and_raise(Faraday::ConnectionFailed, 'some message')
      allow(Settings.sentry).to receive(:dsn).and_return('T')
    end

    it 'makes a call to sentry with request uuid and service unavailable error' do
      expect(Raven).to receive(:extra_context).once.with(request_uuid: nil)
      expect(Raven).to receive(:extra_context).once.with(va_exception_error)
      subject
    end

    it 'makes a call to sentry with appropriate tags' do
      expect(Raven).to receive(:tags_context).once.with(tags_context)
      expect(Raven).to receive(:tags_context).once.with(error: client_type)
      subject
    end

    it 'makes a call to sentry with the appropriate user context' do
      expect(Raven).to receive(:user_context).once.with(user_context)
      subject
    end

    it 'captures the exception for sentry' do
      expect(Raven).to receive(:capture_exception).once
      subject
    end

    it 'has service unavailable status' do
      subject
      expect(response).to have_http_status(:service_unavailable)
    end

    it 'renders service unavailable error' do
      subject
      expect(JSON.parse(response.body)['errors'].first['title']).to eq(expected_error)
    end
  end

  describe '#authenticate_service_account' do
    subject { get :service_account_auth }

    shared_context 'error response' do
      let(:expected_error_json) { { 'errors' => expected_error } }
      let(:sentry_context) do
        { access_token_authorization_header: access_token, access_token_cookie: nil }.compact
      end
      let(:sentry_log_level) { :error }

      it 'renders Malformed Params error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns unauthorized status' do
        expect(subject).to have_http_status(:unauthorized)
      end

      it 'logs error to sentry' do
        expect_any_instance_of(SentryLogging).to receive(:log_message_to_sentry).with(expected_error,
                                                                                      sentry_log_level,
                                                                                      sentry_context)
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
        let(:expiration_time) { Time.zone.now - 1.day }
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
