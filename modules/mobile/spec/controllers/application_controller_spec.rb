# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'

RSpec.describe Mobile::ApplicationController, type: :controller do
  controller do
    attr_reader :payload

    def index
      head :ok
    end

    def append_info_to_payload(payload)
      super
      @payload = payload
    end
  end

  describe 'authentication', aggregate_errors: true do
    let(:error_detail) { JSON.parse(response.body)['errors'].first['detail'] }

    context 'with an invalid authorization header' do
      context 'when the Authentication header is missing' do
        it 'returns forbidden' do
          get :index

          expect(response).to have_http_status(:unauthorized)
          expect(error_detail).to eq('Missing Authorization header')
        end
      end

      context 'when the Authentication header is blank' do
        before { request.headers['Authorization'] = '' }

        it 'returns forbidden' do
          get :index

          expect(response).to have_http_status(:unauthorized)
          expect(error_detail).to eq('Authorization header Bearer token is blank')
        end
      end
    end

    context 'with a valid authorization header' do
      before { request.headers['Authorization'] = "Bearer #{access_token}" }

      context 'with a user who has an inactive iam session' do
        it 'returns forbidden' do
          VCR.use_cassette('iam_ssoe_oauth/introspect_inactive') do
            get :index
          end

          expect(response).to have_http_status(:unauthorized)
          expect(error_detail).to eq('IAM user session is inactive')
        end

        it 'increments the inactive session metric once' do
          expect do
            VCR.use_cassette('iam_ssoe_oauth/introspect_inactive') do
              get :index
            end
          end.to trigger_statsd_increment('iam_ssoe_oauth.inactive_session', times: 1)
        end
      end

      context 'with a user who has a non-cached active iam session' do
        it 'returns ok' do
          VCR.use_cassette('iam_ssoe_oauth/introspect_active') do
            get :index
          end

          expect(response).to have_http_status(:ok)
        end

        it 'increments the session creation success metric once' do
          expect do
            VCR.use_cassette('iam_ssoe_oauth/introspect_active') do
              get :index
            end
          end.to trigger_statsd_increment('iam_ssoe_oauth.create_user_session.success', times: 1)
        end

        it 'measures the session creation execution time' do
          VCR.use_cassette('iam_ssoe_oauth/introspect_active') do
            expect { get :index }
              .to trigger_statsd_measure('api.request.view_runtime')
              .and trigger_statsd_measure('api.request.db_runtime')
              .and trigger_statsd_measure('iam_ssoe_oauth.create_user_session.measure')
          end
        end
      end

      context 'with a user who has a cached active iam session' do
        before { iam_sign_in }

        it 'returns returns ok without hitting the introspect endpoint' do
          get :index

          expect(response).to have_http_status(:ok)
        end
      end

      context 'with a user without vet360 id' do
        before { iam_sign_in(FactoryBot.build(:iam_user, :no_vet360_id)) }

        it 'returns returns ok' do
          get :index
          expect(response).to have_http_status(:ok)
        end

        it 'calls async linking job on first call and does not on second after redis lock is in place' do
          expect(Mobile::V0::Vet360LinkingJob).to receive(:perform_async)
          get :index
          expect(Mobile::V0::Vet360LinkingJob).not_to receive(:perform_async)
          get :index
        end
      end

      context 'with a user with id theft flag set' do
        before { FactoryBot.create(:iam_user, :id_theft_flag) }

        it 'returns unauthorized' do
          VCR.use_cassette('iam_ssoe_oauth/introspect_active') do
            get :index
          end
          expect(response).to have_http_status(:unauthorized)
          expect(error_detail).to eq('User record global deny flag')
        end
      end

      context 'with a user who has a non-cached active iam session via logingov' do
        it 'returns ok and the sign in type is LOGINGOV' do
          VCR.use_cassette('iam_ssoe_oauth/introspect_active_logingov') do
            get :index
          end

          expect(response).to have_http_status(:ok)
          expect(subject.instance_eval { current_user.identity.sign_in[:service_name] }).to eq('oauth_LOGINGOV')
        end
      end
    end

    describe 'authentication' do
      let(:iam_session_token) { Digest::SHA256.hexdigest(access_token)[0..20] }

      context 'without Authentication-Method header' do
        before { request.headers['Authorization'] = "Bearer #{access_token}" }

        it 'uses IAM session authentication' do
          user = iam_sign_in
          expect_any_instance_of(IAMSSOeOAuth::SessionManager).to receive(:find_or_create_user).and_call_original

          VCR.use_cassette('iam_ssoe_oauth/introspect_active') do
            get :index
          end

          expect(response).to have_http_status(:ok)
          expect(controller.payload[:user_uuid]).to eq(user.uuid)
          expect(controller.payload[:session]).to eq(iam_session_token)
        end
      end

      context 'with Authentication-Method header value other than SIS' do
        before do
          request.headers['Authorization'] = "Bearer #{access_token}"
          request.headers['Authentication-Method'] = 'handshake'
        end

        it 'uses IAM session authentication' do
          user = iam_sign_in
          expect_any_instance_of(IAMSSOeOAuth::SessionManager).to receive(:find_or_create_user).and_call_original

          VCR.use_cassette('iam_ssoe_oauth/introspect_active') do
            get :index
          end

          expect(response).to have_http_status(:ok)
          expect(controller.payload[:user_uuid]).to eq(user.uuid)
          expect(controller.payload[:session]).to eq(iam_session_token)
        end
      end

      context 'with Authentication-Method header value of SIS' do
        let(:access_token) { create(:access_token) }
        let(:bearer_token) { SignIn::AccessTokenJwtEncoder.new(access_token:).perform }
        let!(:user) { create(:user, :loa3, uuid: access_token.user_uuid) }

        before do
          request.headers['Authorization'] = "Bearer #{bearer_token}"
          request.headers['Authentication-Method'] = 'SIS'
        end

        it 'uses SIS session authentication' do
          expect_any_instance_of(IAMSSOeOAuth::SessionManager).not_to receive(:find_or_create_user)

          get :index

          expect(response).to have_http_status(:ok)
          expect(controller.payload[:user_uuid]).to eq(access_token.user_uuid)
          expect(controller.payload[:session]).to eq(access_token.session_handle)
        end
      end
    end
  end
end
