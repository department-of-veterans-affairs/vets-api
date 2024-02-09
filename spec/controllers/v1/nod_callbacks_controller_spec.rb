# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::NodCallbacksController, type: :controller do
  let(:params) do
    {
      id: '6ba01111-f3ee-4a40-9d04-234asdfb6abab9c',
      reference: nil,
      to: 'test@test.com',
      status: 'delivered',
      created_at: '2023-01-10T00:04:25.273410Z',
      completed_at: '2023-01-10T00:05:33.255911Z',
      sent_at: '2023-01-10T00:04:25.775363Z',
      notification_type: 'email',
      status_reason: '',
      provider: 'sendgrid'
    }
  end

  describe '#create' do
    before do
      request.headers['Authorization'] = "Bearer #{Settings.nod_vanotify_status_callback.bearer_token}"
    end

    context 'with payload' do
      it 'returns success' do
        post(:create, params:, as: :json)

        expect(response).to have_http_status(:ok)

        res = JSON.parse(response.body)
        expect(res['message']).to eq 'success'
      end
    end
  end

  describe 'authentication' do
    context 'with missing Authorization header' do
      it 'returns 401' do
        request.headers['Authorization'] = nil
        post(:create, params:, as: :json)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with invalid Authorization header' do
      it 'returns 401' do
        request.headers['Authorization'] = 'Bearer foo'
        post(:create, params:, as: :json)
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
