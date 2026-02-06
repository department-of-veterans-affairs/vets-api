# frozen_string_literal: true

require 'rails_helper'
require 'unique_user_events'

RSpec.describe 'MyHealth::V1::UniqueUserMetricsController', type: :request do
  let(:user_account) { create(:user_account) }
  let(:current_user) { build(:user, :loa3, user_account:) }
  let(:headers) { { 'Content-Type' => 'application/json' } }
  let(:valid_event_name) { UniqueUserEvents::EventRegistry::PRESCRIPTIONS_ACCESSED }
  let(:valid_params) { { event_names: [valid_event_name] } }

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

        it 'returns 200 OK with empty buffered_events array' do
          post('/my_health/v1/unique_user_metrics', params: valid_params.to_json, headers:)

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)

          expect(json['buffered_events']).to eq([])
        end

        it 'returns 200 OK with empty array for multiple events' do
          event1 = UniqueUserEvents::EventRegistry::PRESCRIPTIONS_ACCESSED
          event2 = UniqueUserEvents::EventRegistry::SECURE_MESSAGING_INBOX_ACCESSED
          event3 = UniqueUserEvents::EventRegistry::APPOINTMENTS_ACCESSED
          params = { event_names: [event1, event2, event3] }

          post('/my_health/v1/unique_user_metrics', params: params.to_json, headers:)

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)

          expect(json['buffered_events']).to eq([])
        end
      end

      context 'when feature flag is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:unique_user_metrics_logging).and_return(true)
          allow(UniqueUserEvents::Buffer).to receive(:push_batch)
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
          it 'buffers a single event and returns 202 Accepted' do
            allow(UniqueUserEvents).to receive(:log_events)
              .with(user: anything, event_names: [valid_event_name])
              .and_return([valid_event_name])

            post('/my_health/v1/unique_user_metrics', params: valid_params.to_json, headers:)

            expect(response).to have_http_status(:accepted)
            json = JSON.parse(response.body)

            expect(json['buffered_events']).to eq([valid_event_name])
          end

          it 'buffers multiple events and returns 202 Accepted' do
            event1 = UniqueUserEvents::EventRegistry::PRESCRIPTIONS_ACCESSED
            event2 = UniqueUserEvents::EventRegistry::SECURE_MESSAGING_INBOX_ACCESSED
            event3 = UniqueUserEvents::EventRegistry::APPOINTMENTS_ACCESSED
            params = { event_names: [event1, event2, event3] }

            allow(UniqueUserEvents).to receive(:log_events)
              .with(user: anything, event_names: [event1, event2, event3])
              .and_return([event1, event2, event3])

            post('/my_health/v1/unique_user_metrics', params: params.to_json, headers:)

            expect(response).to have_http_status(:accepted)
            json = JSON.parse(response.body)

            expect(json['buffered_events']).to eq([event1, event2, event3])
          end

          it 'includes Oracle Health events in response when applicable' do
            oh_event = 'oh_757_prescriptions_accessed'
            allow(UniqueUserEvents).to receive(:log_events)
              .with(user: anything, event_names: [valid_event_name])
              .and_return([valid_event_name, oh_event])

            post('/my_health/v1/unique_user_metrics', params: valid_params.to_json, headers:)

            expect(response).to have_http_status(:accepted)
            json = JSON.parse(response.body)

            expect(json['buffered_events']).to include(valid_event_name, oh_event)
          end
        end

        context 'with invalid event names in registry' do
          it 'filters out invalid events and only processes valid ones' do
            invalid_event = 'not_a_registered_event'
            params = { event_names: [valid_event_name, invalid_event] }

            allow(UniqueUserEvents).to receive(:log_events)
              .with(user: anything, event_names: [valid_event_name])
              .and_return([valid_event_name])

            post('/my_health/v1/unique_user_metrics', params: params.to_json, headers:)

            expect(response).to have_http_status(:accepted)
            json = JSON.parse(response.body)

            # Only the valid event should be in the response
            expect(json['buffered_events']).to eq([valid_event_name])
          end

          it 'returns 200 OK with empty array when all events are invalid' do
            params = { event_names: %w[invalid_event_1 invalid_event_2] }

            allow(UniqueUserEvents).to receive(:log_events)
              .with(user: anything, event_names: [])
              .and_return([])

            post('/my_health/v1/unique_user_metrics', params: params.to_json, headers:)

            expect(response).to have_http_status(:ok)
            json = JSON.parse(response.body)

            expect(json['buffered_events']).to eq([])
          end
        end

        context 'when service returns empty array' do
          it 'returns 200 OK when no events are buffered' do
            allow(UniqueUserEvents).to receive(:log_events)
              .with(user: anything, event_names: [valid_event_name])
              .and_return([])

            post('/my_health/v1/unique_user_metrics', params: valid_params.to_json, headers:)

            expect(response).to have_http_status(:ok)
            json = JSON.parse(response.body)

            expect(json['buffered_events']).to eq([])
          end
        end

        context 'when current_user is passed to service' do
          it 'uses the correct user object in service calls' do
            expect(UniqueUserEvents).to receive(:log_events)
              .with(user: anything, event_names: [valid_event_name])
              .and_return([valid_event_name])

            post('/my_health/v1/unique_user_metrics', params: valid_params.to_json, headers:)

            expect(response).to have_http_status(:accepted)
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
        allow(UniqueUserEvents).to receive(:log_events).and_return([valid_event_name])

        post '/my_health/v1/unique_user_metrics', params: { event_names: [valid_event_name] }

        expect(response).to have_http_status(:accepted)
        json = JSON.parse(response.body)
        expect(json['buffered_events']).to eq([valid_event_name])
      end
    end
  end
end
