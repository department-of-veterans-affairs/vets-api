# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VANotify Callbacks', type: :request do
  let(:valid_token) { Settings.vanotify.status_callback.bearer_token }
  let(:invalid_token) { 'invalid_token' }
  let(:notification_id) { SecureRandom.uuid }
  let(:callback_params) do
    {
      id: notification_id,
      status: 'delivered',
      notification_type: 'email',
      to: 'user@example.com'
    }
  end
  let(:callback_route) { '/va_notify/callbacks' }

  describe 'POST #notifications' do
    it 'with found notification' do
      notification = VANotify::Notification.create(notification_id: notification_id)
      expect(notification.status).to eq(nil)

      post(callback_route,
           params: callback_params.to_json,
           headers: { 'Authorization' => "Bearer #{valid_token}", 'Content-Type' => 'application/json' })

      expect(response.body).to include('success')
      notification.reload
      expect(notification.status).to eq('delivered')
    end

    it 'with missing notification' do
      post(callback_route,
           params: callback_params.to_json,
           headers: { 'Authorization' => "Bearer #{valid_token}", 'Content-Type' => 'application/json' })

      expect(response.body).to include('success')
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
             params: callback_params,
             headers: { 'Content-Type' => 'application/json' })
        expect(response).to have_http_status(:unauthorized)
        expect(response.body).to include('Unauthorized')
      end
    end
  end
end
