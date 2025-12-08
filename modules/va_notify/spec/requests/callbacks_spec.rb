# frozen_string_literal: true

require 'rails_helper'
require 'va_notify/default_callback'
require 'va_notify/callback_signature_generator'

RSpec.describe 'VANotify Callbacks', type: :request do
  let(:valid_token) { Settings.vanotify.status_callback.bearer_token }
  let(:invalid_token) { 'invalid_token' }
  let(:notification_id) { SecureRandom.uuid }
  let(:callback_params) do
    {
      id: notification_id,
      status: 'delivered',
      notification_type: 'email',
      to: 'user@example.com',
      status_reason: ''
    }
  end
  let(:callback_route) { '/va_notify/callbacks' }

  describe 'POST #create' do
    context 'when :va_notify_custom_bearer_tokens disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:va_notify_custom_bearer_tokens).and_return(false)
      end

      context 'with found notification' do
        it 'updates notification' do
          template_id = SecureRandom.uuid
          notification = VANotify::Notification.create(notification_id:,
                                                       source_location: 'some_location',
                                                       callback_metadata: 'some_callback_metadata',
                                                       template_id:)
          expect(notification.status).to be_nil
          allow(Rails.logger).to receive(:info)
          callback_obj = double('VANotify::DefaultCallback')
          allow(VANotify::DefaultCallback).to receive(:new).and_return(callback_obj)
          allow(callback_obj).to receive(:call)

          post(callback_route,
               params: callback_params.to_json,
               headers: { 'Authorization' => "Bearer #{valid_token}", 'Content-Type' => 'application/json' })

          expect(Rails.logger).to have_received(:info).with(
            "va_notify callbacks - Updating notification: #{notification.id}",
            {
              notification_id: notification.id,
              source_location: 'some_location',
              template_id:,
              callback_metadata: 'some_callback_metadata',
              status_reason: '', status: 'delivered'
            }
          )
          expect(response.body).to include('success')
          notification.reload
          expect(notification.status).to eq('delivered')
        end
      end

      context 'with missing notification' do
        it 'logs info' do
          allow(Rails.logger).to receive(:info)
          post(callback_route,
               params: callback_params.to_json,
               headers: { 'Authorization' => "Bearer #{valid_token}", 'Content-Type' => 'application/json' })

          expect(Rails.logger).to have_received(:info).with(
            "va_notify callbacks - Received update for unknown notification #{notification_id}"
          )

          expect(response.body).to include('success')
        end
      end

      context 'with valid token' do
        it 'returns http success' do
          post(callback_route,
               params: callback_params.to_json,
               headers: { 'Authorization' => "Bearer #{valid_token}", 'Content-Type' => 'application/json' })
          expect(response).to have_http_status(:ok)
          expect(response.body).to include('success')
        end
      end
    end

    context 'when :va_notify_custom_bearer_tokens enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:va_notify_custom_bearer_tokens).and_return(true)
      end

      context 'with multiple bearer tokens' do
        it 'authenticates a valid token' do
          allow(Rails.logger).to receive(:info)
          va_gov_bearer_token = Settings.vanotify.service_callback_tokens.va_gov

          post(callback_route,
               params: callback_params.to_json,
               headers: { 'Authorization' => "Bearer #{va_gov_bearer_token}",
                          'Content-Type' => 'application/json' })

          expect(response).to have_http_status(:ok)
        end

        it 'does not authenticates invalid token' do
          allow(Rails.logger).to receive(:info)

          post(callback_route,
               params: callback_params.to_json,
               headers: { 'Authorization' => "Bearer #{invalid_token}", 'Content-Type' => 'application/json' })

          expect(response).to have_http_status(:unauthorized)
        end
      end
    end

    context 'with invalid token' do
      it 'returns http unauthorized' do
        post(callback_route,
             params: callback_params.to_json,
             headers: { 'Authorization' => "Bearer #{invalid_token}", 'Content-Type' => 'application/json' })

        expect(response).to have_http_status(:unauthorized)
        expect(response.body).to include('Unauthorized')
      end
    end

    context 'without a token' do
      it 'returns http unauthorized' do
        post(callback_route,
             params: callback_params.to_json,
             headers: { 'Content-Type' => 'application/json' })
        expect(response).to have_http_status(:unauthorized)
        expect(response.body).to include('Unauthorized')
      end
    end

    context 'with request-level callback data' do
      context 'when :va_notify_request_level_callbacks disabled' do
        context 'when :va_notify_custom_bearer_tokens is disabled' do
          before do
            allow(Flipper).to receive(:enabled?).with(:va_notify_request_level_callbacks).and_return(false)
            allow(Flipper).to receive(:enabled?).with(:va_notify_custom_bearer_tokens).and_return(false)
          end

          it 'requires bearer token even if x-enp-signature provided' do
            post(callback_route,
                 params: callback_params.to_json,
                 headers: {
                   'Content-Type' => 'application/json',
                   'x-enp-signature' => 'some-signature'
                 })

            expect(response).to have_http_status(:unauthorized)
            expect(response.body).to include('Unauthorized')
          end

          it 'ignores x-enp-signature when bearer token is valid' do
            post(callback_route,
                 params: callback_params.to_json,
                 headers: {
                   'Authorization' => "Bearer #{valid_token}",
                   'Content-Type' => 'application/json',
                   'x-enp-signature' => 'mismatched-signature'
                 })

            expect(response).to have_http_status(:ok)
            expect(response.body).to include('success')
          end
        end

        context 'when :va_notify_custom_bearer_tokens is enabled' do
          before do
            allow(Flipper).to receive(:enabled?).with(:va_notify_request_level_callbacks).and_return(false)
            allow(Flipper).to receive(:enabled?).with(:va_notify_custom_bearer_tokens).and_return(true)
          end

          it 'requires bearer token even if x-enp-signature provided' do
            allow(Rails.logger).to receive(:info)

            post(callback_route,
                 params: callback_params.to_json,
                 headers: {
                   'Content-Type' => 'application/json',
                   'x-enp-signature' => 'some-signature'
                 })

            expect(response).to have_http_status(:unauthorized)
            expect(response.body).to include('Unauthorized')
          end

          it 'authenticates a valid configured token and ignores x-enp-signature' do
            allow(Rails.logger).to receive(:info)
            va_gov_bearer_token = Settings.vanotify.service_callback_tokens.va_gov

            post(callback_route,
                 params: callback_params.to_json,
                 headers: {
                   'Authorization' => "Bearer #{va_gov_bearer_token}",
                   'Content-Type' => 'application/json',
                   'x-enp-signature' => 'mismatched-signature'
                 })

            expect(response).to have_http_status(:ok)
            expect(response.body).to include('success')
          end

          it 'does not authenticate an invalid token even if x-enp-signature provided' do
            allow(Rails.logger).to receive(:info)

            post(callback_route,
                 params: callback_params.to_json,
                 headers: {
                   'Authorization' => "Bearer #{invalid_token}",
                   'Content-Type' => 'application/json',
                   'x-enp-signature' => 'some-signature'
                 })

            expect(response).to have_http_status(:unauthorized)
            expect(response.body).to include('Unauthorized')
          end
        end
      end

      context 'when :va_notify_request_level_callbacks enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:va_notify_request_level_callbacks).and_return(true)
        end

        it 'invalidates signature mis-match' do
          signature = 'mismatched signature'
          notification = instance_double(VANotify::Notification,
                                         service_api_key_path: 'Settings.vanotify.services.check_in.api_key')
          allow(VANotify::Notification).to receive(:find_by).and_return(notification)

          post(callback_route,
               params: callback_params.to_json,
               headers: {
                 'Content-Type' => 'application/json',
                 'x-enp-signature' => signature
               })

          expect(response).to have_http_status(:unauthorized)
        end

        it 'validates header signature' do
          service_api_key_path = 'Settings.vanotify.services.check_in.api_key'
          template_id = SecureRandom.uuid
          notification = VANotify::Notification.create(notification_id:,
                                                       template_id:,
                                                       service_api_key_path:)

          params = {
            id: notification.notification_id,
            status: 'delivered',
            notification_type: 'email',
            to: 'user@example.com',
            status_reason: ''
          }

          signature = VANotify::CallbackSignatureGenerator.call(params.to_json, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')

          post(callback_route,
               params: params.to_json,
               headers: {
                 'Content-Type' => 'application/json',
                 'x-enp-signature' => signature
               })

          expect(response).to have_http_status(:ok)
        end
      end
    end
  end

  describe 'POST #create with retry logic' do
    before do
      allow(Flipper).to receive(:enabled?).with(:va_notify_custom_bearer_tokens).and_return(false)
    end

    context 'when notification is created during retry window' do
      it 'finds notification after retries and tracks metrics' do
        call_count = 0
        allow(VANotify::Notification).to receive(:find_by) do |args|
          call_count += 1
          if call_count >= 3
            VANotify::Notification.create(
              notification_id: args[:notification_id],
              source_location: 'some_location',
              callback_metadata: 'some_callback_metadata',
              template_id: SecureRandom.uuid
            )
          end
        end

        allow(StatsD).to receive(:increment)
        allow(Rails.logger).to receive(:debug)

        post(callback_route,
             params: callback_params.to_json,
             headers: { 'Authorization' => "Bearer #{valid_token}", 'Content-Type' => 'application/json' })

        expect(response).to have_http_status(:ok)
        expect(call_count).to eq(4)
        expect(StatsD).to have_received(:increment)
          .with('va_notify.callback.notification_found', { tags: ['attempt: 3'] })
        expect(Rails.logger).to have_received(:debug).at_least(:once)
                                                     .with(/Notification not found with id #{notification_id}/)
      end
    end

    context 'when notification is never found after all retries' do
      it 'returns success but logs warning and tracks failure metric' do
        allow(VANotify::Notification).to receive(:find_by).and_return(nil)
        allow(StatsD).to receive(:increment)
        allow(Rails.logger).to receive(:warn)
        allow(Rails.logger).to receive(:debug)
        allow(Rails.logger).to receive(:error)

        post(callback_route,
             params: callback_params.to_json,
             headers: { 'Authorization' => "Bearer #{valid_token}", 'Content-Type' => 'application/json' })

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('success')

        expect(Rails.logger).to have_received(:error)
          .with("va_notify callbacks - Notification not found with id #{notification_id} after 5 attempts")
      end
    end

    context 'retry timing behavior' do
      it 'uses exponential backoff delays' do
        allow(VANotify::Notification).to receive(:find_by).and_return(nil)
        allow(Rails.logger).to receive(:debug)
        allow(Rails.logger).to receive(:error)
        allow(Rails.logger).to receive(:warn)
        allow(StatsD).to receive(:increment)

        # Track sleep calls to verify exponential backoff
        sleep_durations = []
        allow_any_instance_of(VANotify::CallbacksController).to receive(:sleep) do |_, duration|
          sleep_durations << duration
        end

        post(callback_route,
             params: callback_params.to_json,
             headers: { 'Authorization' => "Bearer #{valid_token}", 'Content-Type' => 'application/json' })

        # Should have 4 sleep calls (not on final attempt)
        # Exponential backoff: 0.05, 0.1, 0.2, 0.4 seconds
        expect(sleep_durations.length).to eq(4)
        expect(sleep_durations[0]).to eq(0.05)
        expect(sleep_durations[1]).to eq(0.1)
        expect(sleep_durations[2]).to eq(0.2)
        expect(sleep_durations[3]).to eq(0.4)
      end
    end
  end
end
