# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'

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

  describe 'authentication', :aggregate_errors do
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

      context 'with a user with id theft flag set' do
        before { create(:iam_user, :id_theft_flag) }

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
        let(:access_token) { create(:access_token, audience: ['vamobile']) }
        let(:bearer_token) { SignIn::AccessTokenJwtEncoder.new(access_token:).perform }
        let!(:user) { create(:user, :loa3, uuid: access_token.user_uuid) }
        let(:deceased_date) { nil }
        let(:id_theft_flag) { false }
        let(:mpi_profile) { build(:mpi_profile, deceased_date:, id_theft_flag:) }

        before do
          request.headers['Authorization'] = "Bearer #{bearer_token}"
          request.headers['Authentication-Method'] = 'SIS'
          allow_any_instance_of(MPIData).to receive(:profile).and_return(mpi_profile)
        end

        it 'uses SIS session authentication' do
          expect_any_instance_of(IAMSSOeOAuth::SessionManager).not_to receive(:find_or_create_user)

          get :index

          expect(response).to have_http_status(:ok)
          expect(controller.payload[:user_uuid]).to eq(access_token.user_uuid)
          expect(controller.payload[:session]).to eq(access_token.session_handle)
        end

        context 'when the access_token audience is invalid' do
          let(:access_token) { create(:access_token, audience: ['invalid']) }

          it 'returns unauthorized' do
            get :index

            expect(response).to have_http_status(:unauthorized)
          end
        end

        context 'when validating the user\'s MPI profile' do
          context 'and the MPI profile has a deceased date' do
            let(:deceased_date) { '20020202' }
            let(:expected_error) { 'Death Flag Detected' }

            it 'raises an MPI locked account error' do
              get :index

              expect(response).to have_http_status(:internal_server_error)
              error_body = JSON.parse(response.body)['errors'].first
              expect(error_body['meta']['exception']).to eq(expected_error)
            end
          end

          context 'and the MPI profile has an id theft flag' do
            let(:id_theft_flag) { true }
            let(:expected_error) { 'Theft Flag Detected' }

            it 'raises an MPI locked account error' do
              get :index

              expect(response).to have_http_status(:internal_server_error)
              error_body = JSON.parse(response.body)['errors'].first
              expect(error_body['meta']['exception']).to eq(expected_error)
            end
          end
        end
      end
    end
  end
end
