# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/attr_package'
require 'va_notify/default_callback'
require 'va_notify/callback_signature_generator'

RSpec.describe 'VANotify Callbacks', type: :request do
  let(:valid_token) { Settings.vanotify.service_callback_tokens&.to_h&.values&.first }
  let(:invalid_token) { 'invalid_token' }
  let(:notification_id) { SecureRandom.uuid }
  let(:attr_package_params_cache_key) { SecureRandom.hex(32) }
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
    context 'when authenticating' do
      context 'with valid token' do
        before do
          allow(Flipper).to receive(:enabled?).with(:va_notify_delivery_status_update_job).and_return(false)
        end

        context 'with found notification' do
          let(:template_id) { SecureRandom.uuid }
          let!(:notification) do
            VANotify::Notification.create(notification_id:,
                                          source_location: 'some_location',
                                          callback_metadata: 'some_callback_metadata',
                                          template_id:)
          end

          it 'updates notification' do
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

        context 'when :va_notify_delivery_status_update_job enabled' do
          before do
            allow(Flipper).to receive(:enabled?).with(:va_notify_delivery_status_update_job).and_return(true)
            allow(Sidekiq::AttrPackage).to receive(:create).and_return(attr_package_params_cache_key)
            allow(VANotify::DeliveryStatusUpdateJob).to receive(:perform_async)
          end

          it 'stores notification params in AttrPackage' do
            post(callback_route,
                 params: callback_params.to_json,
                 headers: { 'Authorization' => "Bearer #{valid_token}", 'Content-Type' => 'application/json' })

            expect(Sidekiq::AttrPackage).to have_received(:create).with(
              status: 'delivered',
              notification_type: 'email',
              to: 'user@example.com',
              status_reason: ''
            )
          end

          it 'passes cache key to DeliveryStatusUpdateJob' do
            post(callback_route,
                 params: callback_params.to_json,
                 headers: { 'Authorization' => "Bearer #{valid_token}", 'Content-Type' => 'application/json' })

            expect(VANotify::DeliveryStatusUpdateJob).to have_received(:perform_async).with(
              notification_id,
              attr_package_params_cache_key
            )
          end

          it 'logs enqueued job with notification_id and cache key' do
            allow(Rails.logger).to receive(:info)

            post(callback_route,
                 params: callback_params.to_json,
                 headers: { 'Authorization' => "Bearer #{valid_token}", 'Content-Type' => 'application/json' })

            expect(Rails.logger).to have_received(:info).with(
              'va_notify callbacks - Enqueued DeliveryStatusUpdateJob',
              { notification_id:, attr_package_params_cache_key: }
            )
          end
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
        before do
          allow(Flipper).to receive(:enabled?).with(:va_notify_request_level_callbacks).and_return(false)
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

      context 'when :va_notify_request_level_callbacks enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:va_notify_request_level_callbacks).and_return(true)
        end

        it 'invalidates signature mis-match' do
          signature = 'mismatched signature'
          notification = instance_double(VANotify::Notification,
                                         service_id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
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
          service_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
          template_id = SecureRandom.uuid
          notification = VANotify::Notification.create(notification_id:,
                                                       template_id:,
                                                       service_id:)

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
end
