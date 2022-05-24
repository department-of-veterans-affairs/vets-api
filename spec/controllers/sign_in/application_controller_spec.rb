# frozen_string_literal: true

require 'rails_helper'
require 'rx/client'

RSpec.describe SignIn::ApplicationController, type: :controller do
  controller do
    attr_reader :payload

    def index
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
  end

  before do
    routes.draw do
      get 'client_connection_failed' => 'sign_in/application#client_connection_failed'
      get 'index' => 'sign_in/application#index'
    end
  end

  describe '#authentication' do
    subject { get :index }

    context 'when authorization header does not exist' do
      let(:authorization_header) { nil }
      let(:expected_error) { 'Access token JWT is malformed' }
      let(:expected_error_json) { { 'errors' => expected_error } }

      it 'renders Malformed Params error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns unauthorized status' do
        expect(subject).to have_http_status(:unauthorized)
      end
    end

    context 'when authorization header exists' do
      let(:authorization) { "Bearer #{access_token}" }
      let(:access_token) { 'some-access-token' }

      before do
        request.headers['Authorization'] = authorization
      end

      context 'and access_token is some arbitrary value' do
        let(:access_token) { 'some-arbitrary-access-token' }
        let(:expected_error) { 'Access token JWT is malformed' }
        let(:expected_error_json) { { 'errors' => expected_error } }

        it 'renders Malformed Params error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns unauthorized status' do
          expect(subject).to have_http_status(:unauthorized)
        end
      end

      context 'and access_token is an expired JWT' do
        let(:access_token_object) { create(:access_token, expiration_time: expiration_time) }
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
        let!(:user) { create(:user, :loa3, uuid: access_token_object.user_uuid) }
        let(:user_serializer) { SignIn::IntrospectSerializer.new(user) }
        let(:expected_introspect_response) { JSON.parse(user_serializer.to_json) }

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
    let(:access_token_object) { create(:access_token) }
    let(:access_token) { SignIn::AccessTokenJwtEncoder.new(access_token: access_token_object).perform }
    let(:user_account) { UserAccount.find(access_token_object.user_uuid) }
    let(:va_exception_error) do
      {
        va_exception_errors: [{
          title: 'Service unavailable', detail: 'Backend Service Outage', code: '503', status: '503'
        }]
      }
    end
    let(:controller_name) { 'application' }
    let(:client_type) { 'mhv_session' }
    let(:tags_context) { { controller_name: controller_name, sign_in_method: nil, sign_in_acct_type: nil } }
    let(:loa) { { current: 3, highest: 3 } }
    let(:user_context) do
      { id: access_token_object.user_uuid, authn_context: nil, loa: loa, mhv_icn: user_account.icn }
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
end
