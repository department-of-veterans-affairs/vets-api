# frozen_string_literal: true

require 'rails_helper'
require_relative '../rails_helper'

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
          end.to trigger_statsd_increment('mobile.application_controller.authenticate.failure', times: 1)
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
          end.to trigger_statsd_increment('mobile.application_controller.authenticate.failure', times: 1)
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

        it 'increments the failure metric once' do
          expect do
            VCR.use_cassette('iam_ssoe_oauth/introspect_inactive') do
              get :index
            end
          end.to trigger_statsd_increment('mobile.application_controller.authenticate.failure', times: 1)
        end

        it 'increments the inactive session metric once' do
          expect do
            VCR.use_cassette('iam_ssoe_oauth/introspect_inactive') do
              get :index
            end
          end.to trigger_statsd_increment('mobile.application_controller.create_iam_session.inactive_session', times: 1)
        end
      end

      context 'with a user who has an active iam session' do
        it 'returns ok' do
          VCR.use_cassette('iam_ssoe_oauth/introspect_active') do
            get :index
          end

          expect(response).to have_http_status(:ok)
        end

        it 'increments the success metric once' do
          expect do
            VCR.use_cassette('iam_ssoe_oauth/introspect_active') do
              get :index
            end
          end.to trigger_statsd_increment('mobile.application_controller.authenticate.success', times: 1)
        end

        it 'measures the session creation execution time' do
          expect(StatsD).to receive(:measure).with('api.request.view_runtime', any_args)
          expect(StatsD).to receive(:measure).with('api.request.db_runtime', any_args)
          expect(StatsD).to receive(:measure).with('mobile.application_controller.create_iam_session.measure', any_args)

          VCR.use_cassette('iam_ssoe_oauth/introspect_active') do
            get :index
          end
        end
      end

      context 'with a user who has a cached iam session' do
        before { sign_in }

        it 'returns returns ok without hitting the introspect endpoint' do
          get :index
          puts response.body
          expect(response).to have_http_status(:ok)
        end

        it 'increments the success metric once' do
          expect do
            VCR.use_cassette('iam_ssoe_oauth/introspect_active') do
              get :index
            end
          end.to trigger_statsd_increment('mobile.application_controller.authenticate.success', times: 1)
        end
      end
    end
  end
end
