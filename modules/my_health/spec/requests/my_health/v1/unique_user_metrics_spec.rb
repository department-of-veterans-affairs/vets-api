# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'MyHealth::V1::UniqueUserMetricsController', type: :request do
  let(:user_account) { create(:user_account) }
  let(:current_user) { build(:user, :loa3, user_account:) }
  let(:headers) { { 'Content-Type' => 'application/json' } }
  let(:valid_params) { { event_names: ['mhv_landing_page_accessed'] } }

  describe 'POST /my_health/v1/unique_user_metrics' do
    context 'when user is not authenticated' do
      it 'returns 401 Unauthorized' do
        post('/my_health/v1/unique_user_metrics', params: valid_params.to_json, headers:)

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when user is authenticated' do
      before do
        sign_in_as(current_user)
      end

      context 'when feature flag is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:unique_user_metrics_logging).and_return(false)
        end

        it 'returns 501 Not Implemented' do
          post('/my_health/v1/unique_user_metrics', params: valid_params.to_json, headers:)

          expect(response).to have_http_status(:not_implemented)
          json = JSON.parse(response.body)
          expect(json['errors'].first['title']).to eq('Not Implemented')
          expect(json['errors'].first['detail']).to eq('Unique user metrics logging is not currently available')
        end
      end

      context 'when feature flag is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:unique_user_metrics_logging).and_return(true)
        end

        context 'with invalid parameters' do
          it 'returns 400 when event_names is missing' do
            post('/my_health/v1/unique_user_metrics', params: {}.to_json, headers:)

            expect(response).to have_http_status(:bad_request)
            json = JSON.parse(response.body)
            expect(json['errors'].first['title']).to eq('Missing parameter')
          end

          it 'returns 400 when event_names is not an array' do
            params = { event_names: 'not_an_array' }
            post('/my_health/v1/unique_user_metrics', params: params.to_json, headers:)

            expect(response).to have_http_status(:bad_request)
            json = JSON.parse(response.body)
            expect(json['errors'].first['title']).to eq('Invalid field value')
            expect(json['errors'].first['detail']).to eq('"must be an array" is not a valid value for "event_names"')
          end

          it 'returns 400 when event_names is an empty array' do
            params = { event_names: [] }
            post('/my_health/v1/unique_user_metrics', params: params.to_json, headers:)

            expect(response).to have_http_status(:bad_request)
            json = JSON.parse(response.body)
            expect(json['errors'].first['title']).to eq('Missing parameter')
          end

          it 'returns 400 when event_names contains non-string values' do
            params = { event_names: ['valid_event', 123, 'another_event'] }
            post('/my_health/v1/unique_user_metrics', params: params.to_json, headers:)

            expect(response).to have_http_status(:bad_request)
            json = JSON.parse(response.body)
            expect(json['errors'].first['title']).to eq('Invalid field value')
            expect(json['errors'].first['detail'])
              .to eq('"must contain non-empty strings" is not a valid value for "event_names"')
          end

          it 'returns 400 when event_names contains empty strings' do
            params = { event_names: ['valid_event', '', 'another_event'] }
            post('/my_health/v1/unique_user_metrics', params: params.to_json, headers:)

            expect(response).to have_http_status(:bad_request)
            json = JSON.parse(response.body)
            expect(json['errors'].first['title']).to eq('Invalid field value')
            expect(json['errors'].first['detail'])
              .to eq('"must contain non-empty strings" is not a valid value for "event_names"')
          end
        end

        context 'with valid parameters' do
          before do
            allow(UniqueUserEvents).to receive(:log_event).and_return(true)
          end

          it 'logs a single new event and returns 201 Created' do
            allow(UniqueUserEvents).to receive(:log_event)
              .with(user_id: current_user.uuid, event_name: 'mhv_landing_page_accessed')
              .and_return(true)

            post('/my_health/v1/unique_user_metrics', params: valid_params.to_json, headers:)

            expect(response).to have_http_status(:created)
            json = JSON.parse(response.body)

            expect(json['results']).to be_an(Array)
            expect(json['results'].length).to eq(1)
            expect(json['results'].first['event_name']).to eq('mhv_landing_page_accessed')
            expect(json['results'].first['status']).to eq('created')
            expect(json['results'].first['new_event']).to be(true)
          end

          it 'logs a duplicate event and returns 200 OK' do
            allow(UniqueUserEvents).to receive(:log_event)
              .with(user_id: current_user.uuid, event_name: 'mhv_landing_page_accessed')
              .and_return(false)

            post('/my_health/v1/unique_user_metrics', params: valid_params.to_json, headers:)

            expect(response).to have_http_status(:ok)
            json = JSON.parse(response.body)

            expect(json['results'].first['event_name']).to eq('mhv_landing_page_accessed')
            expect(json['results'].first['status']).to eq('exists')
            expect(json['results'].first['new_event']).to be(false)
          end

          it 'processes multiple events successfully and returns 201 when any are new' do
            params = { event_names: %w[mhv_landing_page_accessed secure_messaging_accessed
                                       prescriptions_accessed] }

            allow(UniqueUserEvents).to receive(:log_event)
              .with(user_id: current_user.uuid, event_name: 'mhv_landing_page_accessed')
              .and_return(true)
            allow(UniqueUserEvents).to receive(:log_event)
              .with(user_id: current_user.uuid, event_name: 'secure_messaging_accessed')
              .and_return(false)
            allow(UniqueUserEvents).to receive(:log_event)
              .with(user_id: current_user.uuid, event_name: 'prescriptions_accessed')
              .and_return(true)

            post('/my_health/v1/unique_user_metrics', params: params.to_json, headers:)

            expect(response).to have_http_status(:created)
            json = JSON.parse(response.body)

            expect(json['results']).to be_an(Array)
            expect(json['results'].length).to eq(3)

            # Check first event (new)
            expect(json['results'][0]['event_name']).to eq('mhv_landing_page_accessed')
            expect(json['results'][0]['status']).to eq('created')
            expect(json['results'][0]['new_event']).to be(true)

            # Check second event (existing)
            expect(json['results'][1]['event_name']).to eq('secure_messaging_accessed')
            expect(json['results'][1]['status']).to eq('exists')
            expect(json['results'][1]['new_event']).to be(false)

            # Check third event (new)
            expect(json['results'][2]['event_name']).to eq('prescriptions_accessed')
            expect(json['results'][2]['status']).to eq('created')
            expect(json['results'][2]['new_event']).to be(true)
          end

          it 'processes multiple duplicate events and returns 200 OK' do
            params = { event_names: %w[mhv_landing_page_accessed secure_messaging_accessed] }

            allow(UniqueUserEvents).to receive(:log_event).and_return(false)

            post('/my_health/v1/unique_user_metrics', params: params.to_json, headers:)

            expect(response).to have_http_status(:ok)
            json = JSON.parse(response.body)

            expect(json['results']).to be_an(Array)
            expect(json['results'].length).to eq(2)
            expect(json['results'].all? { |result| result['status'] == 'exists' }).to be(true)
            expect(json['results'].all? { |result| result['new_event'] == false }).to be(true)
          end
        end

        context 'when service layer raises an error' do
          before do
            allow(UniqueUserEvents).to receive(:log_event).and_raise(StandardError, 'Service error')
            allow(Rails.logger).to receive(:error)
          end

          it 'handles service errors gracefully and returns error status for affected events' do
            params = { event_names: %w[mhv_landing_page_accessed secure_messaging_accessed] }

            post('/my_health/v1/unique_user_metrics', params: params.to_json, headers:)

            expect(response).to have_http_status(:ok)
            json = JSON.parse(response.body)

            expect(json['results']).to be_an(Array)
            expect(json['results'].length).to eq(2)

            json['results'].each do |result|
              expect(result['status']).to eq('error')
              expect(result['new_event']).to be(false)
              expect(result['error']).to eq('Failed to process event')
            end

            # Verify error logging
            expect(Rails.logger).to have_received(:error).twice
          end

          it 'processes mixed success and error events' do
            params = { event_names: %w[success_event error_event] }

            allow(UniqueUserEvents).to receive(:log_event)
              .with(user_id: current_user.uuid, event_name: 'success_event')
              .and_return(true)
            allow(UniqueUserEvents).to receive(:log_event)
              .with(user_id: current_user.uuid, event_name: 'error_event')
              .and_raise(StandardError, 'Service error')

            post('/my_health/v1/unique_user_metrics', params: params.to_json, headers:)

            expect(response).to have_http_status(:created)
            json = JSON.parse(response.body)

            expect(json['results'].length).to eq(2)

            # Success event
            expect(json['results'][0]['event_name']).to eq('success_event')
            expect(json['results'][0]['status']).to eq('created')
            expect(json['results'][0]['new_event']).to be(true)

            # Error event
            expect(json['results'][1]['event_name']).to eq('error_event')
            expect(json['results'][1]['status']).to eq('error')
            expect(json['results'][1]['new_event']).to be(false)
            expect(json['results'][1]['error']).to eq('Failed to process event')
          end
        end

        context 'when current_user.uuid is called' do
          it 'uses the correct user UUID in service calls' do
            expect(UniqueUserEvents).to receive(:log_event)
              .with(user_id: current_user.uuid, event_name: 'mhv_landing_page_accessed')
              .and_return(true)

            post('/my_health/v1/unique_user_metrics', params: valid_params.to_json, headers:)

            expect(response).to have_http_status(:created)
          end
        end
      end
    end

    context 'when request content type is not JSON' do
      before do
        sign_in_as(current_user)
        allow(Flipper).to receive(:enabled?).with(:unique_user_metrics_logging).and_return(true)
      end

      it 'handles form-encoded parameters correctly' do
        allow(UniqueUserEvents).to receive(:log_event).and_return(true)

        post '/my_health/v1/unique_user_metrics', params: { event_names: ['mhv_landing_page_accessed'] }

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['results'].first['event_name']).to eq('mhv_landing_page_accessed')
      end
    end
  end
end
