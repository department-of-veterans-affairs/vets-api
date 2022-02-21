# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'

RSpec.describe Mobile::ApplicationController, type: :controller do
  controller do
    def index
      head :ok
    end
  end

  describe 'authentication' do
    let(:error_detail) { JSON.parse(response.body)['errors'].first['detail'] }

    context 'with an invalid authorization header' do
      context 'when the Authentication header is missing' do
        it 'returns forbidden' do
          get :index

          expect(response).to have_http_status(:unauthorized)
          expect(error_detail).to eq('Missing Authorization header')
        end

        it 'increments the failure metric once' do
          expect do
            get :index
          end.to trigger_statsd_increment('mobile.authentication.failure', times: 1)
        end
      end

      context 'when the Authentication header is blank' do
        before { request.headers['Authorization'] = '' }

        it 'returns forbidden' do
          get :index

          expect(response).to have_http_status(:unauthorized)
          expect(error_detail).to eq('Authorization header Bearer token is blank')
        end

        it 'increments the failure metric once' do
          expect do
            get :index
          end.to trigger_statsd_increment('mobile.authentication.failure', times: 1)
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

        it 'increments the auth failure metric once' do
          expect do
            VCR.use_cassette('iam_ssoe_oauth/introspect_inactive') do
              get :index
            end
          end.to trigger_statsd_increment('mobile.authentication.failure', times: 1)
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

        it 'increments the auth success metric once' do
          expect do
            VCR.use_cassette('iam_ssoe_oauth/introspect_active') do
              get :index
            end
          end.to trigger_statsd_increment('mobile.authentication.success', times: 1)
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

        it 'increments the auth success metric once' do
          expect do
            get :index
          end.to trigger_statsd_increment('mobile.authentication.success', times: 1)
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
  end
end
