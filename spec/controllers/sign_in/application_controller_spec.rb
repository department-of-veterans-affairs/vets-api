# frozen_string_literal: true

require 'rails_helper'
require 'rx/client'

RSpec.describe SignIn::ApplicationController, type: :controller do
  controller do
    skip_before_action :authenticate, only: %w[index_optional_auth access_token_auth access_token_optional_auth]
    before_action :load_user, only: %(index_optional_auth)
    before_action lambda {
                    access_token_authenticate(skip_render_error: params[:skip_render_error] == 'true')
                  }, only: %(access_token_auth)

    attr_reader :payload

    def index
      head :ok
    end

    def index_optional_auth
      head :ok
    end

    def access_token_auth
      head :ok
    end

    def access_token_optional_auth
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
      get 'access_token_auth' => 'sign_in/application#access_token_auth'
    end
  end

  describe '#authentication' do
    subject { get :index }

    shared_context 'error response' do
      let(:expected_error) { 'Access token JWT is malformed' }
      let(:expected_error_json) { { 'errors' => expected_error } }

      it 'renders Malformed Params error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns unauthorized status' do
        expect(subject).to have_http_status(:unauthorized)
      end
    end

    shared_context 'error response with sentry log' do
      let(:expected_error) { 'Access token JWT is malformed' }
      let(:sentry_context) do
        { access_token_authorization_header: access_token, access_token_cookie: }.compact
      end
      let(:sentry_log_level) { :error }

      it_behaves_like 'error response'

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
        let!(:user) do
          create(:user, :loa3, uuid: access_token_object.user_uuid, session_handle: access_token_object.session_handle)
        end
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

    shared_context 'mpi profile validation' do
      before { allow_any_instance_of(SignIn::UserLoader).to receive(:find_valid_user).and_return(nil) }

      context 'and the MPI profile has a deceased date' do
        let(:deceased_date) { '20020202' }
        let(:expected_error) { 'Death Flag Detected' }

        it 'raises an MPI locked account error' do
          response = subject
          expect(response).to have_http_status(:internal_server_error)
          error_body = JSON.parse(response.body)['errors'].first
          expect(error_body['meta']['exception']).to eq(expected_error)
        end
      end

      context 'and the MPI profile has an id theft flag' do
        let(:id_theft_flag) { true }
        let(:expected_error) { 'Theft Flag Detected' }

        it 'raises an MPI locked account error' do
          response = subject
          expect(response).to have_http_status(:internal_server_error)
          error_body = JSON.parse(response.body)['errors'].first
          expect(error_body['meta']['exception']).to eq(expected_error)
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

          it_behaves_like 'error response with sentry log'
        end

        context 'and access_token is an expired JWT' do
          let(:access_token_object) { create(:access_token, expiration_time:) }
          let(:access_token_cookie) { SignIn::AccessTokenJwtEncoder.new(access_token: access_token_object).perform }
          let(:expiration_time) { 1.day.ago }
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
            create(:user,
                   :loa3,
                   uuid: access_token_object.user_uuid,
                   fingerprint: request.remote_ip,
                   session_handle: access_token_object.session_handle)
          end
          let(:user_serializer) { SignIn::IntrospectSerializer.new(user) }
          let(:expected_introspect_response) { JSON.parse(user_serializer.to_json) }
          let(:deceased_date) { nil }
          let(:id_theft_flag) { false }
          let(:mpi_profile) { build(:mpi_profile, deceased_date:, id_theft_flag:) }

          before { allow_any_instance_of(MPIData).to receive(:profile).and_return(mpi_profile) }

          it_behaves_like 'user fingerprint validation'

          it_behaves_like 'mpi profile validation'

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

        it_behaves_like 'error response with sentry log'
      end

      context 'and access_token is an expired JWT' do
        let(:access_token_object) { create(:access_token, expiration_time:) }
        let(:access_token) { SignIn::AccessTokenJwtEncoder.new(access_token: access_token_object).perform }
        let(:expiration_time) { 1.day.ago }
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
        let(:deceased_date) { nil }
        let(:id_theft_flag) { false }
        let(:mpi_profile) { build(:mpi_profile, deceased_date:, id_theft_flag:) }

        before { allow_any_instance_of(MPIData).to receive(:profile).and_return(mpi_profile) }

        it_behaves_like 'user fingerprint validation'

        it_behaves_like 'mpi profile validation'

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
        let!(:user) do
          create(:user, :loa3, uuid: access_token_object.user_uuid, session_handle: access_token_object.session_handle)
        end
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

    shared_context 'mpi profile validation' do
      context 'and the MPI profile has a deceased date' do
        let(:deceased_date) { '20020202' }
        let(:expected_error) { 'Death Flag Detected' }

        it 'raises an MPI locked account error' do
          response = subject
          expect(response).to have_http_status(:internal_server_error)
          error_body = JSON.parse(response.body)['errors'].first
          expect(error_body['meta']['exception']).to eq(expected_error)
        end
      end

      context 'and the MPI profile has an id theft flag' do
        let(:id_theft_flag) { true }
        let(:expected_error) { 'Theft Flag Detected' }

        it 'raises an MPI locked account error' do
          response = subject
          expect(response).to have_http_status(:internal_server_error)
          error_body = JSON.parse(response.body)['errors'].first
          expect(error_body['meta']['exception']).to eq(expected_error)
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
          let(:expiration_time) { 1.day.ago }
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
          let(:deceased_date) { nil }
          let(:id_theft_flag) { false }
          let(:mpi_profile) { build(:mpi_profile, deceased_date:, id_theft_flag:) }

          before { allow_any_instance_of(MPIData).to receive(:profile).and_return(mpi_profile) }

          it_behaves_like 'user fingerprint validation'

          it_behaves_like 'mpi profile validation'

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
        let(:expiration_time) { 1.day.ago }
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
        let(:deceased_date) { nil }
        let(:id_theft_flag) { false }
        let(:mpi_profile) { build(:mpi_profile, deceased_date:, id_theft_flag:) }

        before { allow_any_instance_of(MPIData).to receive(:profile).and_return(mpi_profile) }

        it_behaves_like 'user fingerprint validation'

        it_behaves_like 'mpi profile validation'

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

  describe '#access_token_authenticate' do
    subject { get :access_token_auth, params: { skip_render_error: } }

    let(:skip_render_error) { false }

    shared_context 'error response' do
      let(:expected_error) { 'Access token JWT is malformed' }
      let(:expected_error_json) { { 'errors' => expected_error } }

      it 'returns unauthorized status' do
        expect(subject).to have_http_status(:unauthorized)
      end

      it 'renders Malformed Params error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      context 'when skip_error_handling is true' do
        let(:skip_render_error) { true }

        it 'returns ok status' do
          expect(subject).to have_http_status(:ok)
        end

        it 'returns a nil body' do
          expect(subject.body).to be_empty
        end
      end
    end

    shared_context 'error response with sentry log' do
      let(:expected_error) { 'Access token JWT is malformed' }
      let(:sentry_context) do
        { access_token_authorization_header: access_token, access_token_cookie: }.compact
      end
      let(:sentry_log_level) { :error }

      it 'logs error to sentry' do
        expect_any_instance_of(SentryLogging).to receive(:log_message_to_sentry).with(expected_error,
                                                                                      sentry_log_level,
                                                                                      sentry_context)
        subject
      end

      context 'when skip_error_handling is true' do
        let(:skip_render_error) { true }

        it 'does not log an error to sentry' do
          expect_any_instance_of(SentryLogging).not_to receive(:log_message_to_sentry)
          subject
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

          it_behaves_like 'error response with sentry log'
        end

        context 'and access_token is an expired JWT' do
          let(:access_token_object) { create(:access_token, expiration_time:) }
          let(:access_token_cookie) { SignIn::AccessTokenJwtEncoder.new(access_token: access_token_object).perform }
          let(:expiration_time) { 1.day.ago }
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

      context 'and access_token equals the string undefined' do
        let(:access_token) { 'undefined' }

        it_behaves_like 'error response'
      end

      context 'and access_token is an expired JWT' do
        let(:access_token_object) { create(:access_token, expiration_time:) }
        let(:access_token) { SignIn::AccessTokenJwtEncoder.new(access_token: access_token_object).perform }
        let(:expiration_time) { 1.day.ago }
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

        it 'returns ok status' do
          expect(subject).to have_http_status(:ok)
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
      expect(Sentry).to receive(:set_extras).once.with(request_uuid: nil)
      expect(Sentry).to receive(:set_extras).once.with(va_exception_error)
      subject
    end

    it 'makes a call to sentry with appropriate tags' do
      expect(Sentry).to receive(:set_tags).once.with(tags_context)
      expect(Sentry).to receive(:set_tags).once.with(error: client_type)
      subject
    end

    it 'makes a call to sentry with the appropriate user context' do
      expect(Sentry).to receive(:set_user).once.with(user_context)
      subject
    end

    it 'captures the exception for sentry' do
      expect(Sentry).to receive(:capture_exception).once
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
end
