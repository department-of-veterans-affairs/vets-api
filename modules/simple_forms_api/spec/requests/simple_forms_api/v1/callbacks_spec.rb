# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SimpleFormsApi::V1::Callbacks', type: :request do
  let(:params) do
    {
      id: SecureRandom.uuid,
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
    let(:headers) do
      { 'Authorization' => "Bearer #{Settings.simple_forms_vanotify_status_callback.bearer_token}" }
    end

    context 'with payload' do
      context 'Flipper for simple_forms_callbacks_endpoint' do
        after { Flipper.disable(:simple_forms_callbacks_endpoint) }

        context 'when flipped on' do
          before { Flipper.enable(:simple_forms_callbacks_endpoint) }

          it 'returns success' do
            post('/simple_forms_api/v1/callbacks', params:, headers:)

            expect(response).to have_http_status(:ok)
          end
        end

        context 'when flipped off' do
          before { Flipper.disable(:simple_forms_callbacks_endpoint) }

          it 'returns 500' do
            post('/simple_forms_api/v1/callbacks', params:, headers:)

            expect(response).to have_http_status(:not_found)
          end
        end
      end
    end
  end

  describe 'authentication' do
    context 'with missing Authorization header' do
      let(:headers) { {} }

      it 'returns 401' do
        post('/simple_forms_api/v1/callbacks', params:, headers:)

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with invalid Authorization header' do
      let(:headers) { { 'Authorization' => 'Bearer rawr rawr' } }

      it 'returns 401' do
        post('/simple_forms_api/v1/callbacks', params:, headers:)

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
