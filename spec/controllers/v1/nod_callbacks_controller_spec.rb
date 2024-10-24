# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::NodCallbacksController, type: :controller do
  let(:notification_id) { SecureRandom.uuid }
  let(:reference) { 'reference-id' }
  let(:status) { 'delivered' }
  let(:params) do
    {
      id: notification_id,
      reference: reference,
      to: 'test@test.com',
      status:,
      created_at: '2023-01-10T00:04:25.273410Z',
      completed_at: '2023-01-10T00:05:33.255911Z',
      sent_at: '2023-01-10T00:04:25.775363Z',
      notification_type: 'email',
      status_reason: '',
      provider: 'sendgrid'
    }.stringify_keys!
  end

  describe '#create' do
    before do
      request.headers['Authorization'] = "Bearer #{Settings.nod_vanotify_status_callback.bearer_token}"
      Flipper.enable(:nod_callbacks_endpoint)

      allow(DecisionReviewNotificationAuditLog).to receive(:create!)
    end

    context 'the record saved without an issue' do
      it 'returns success' do
        expect(DecisionReviewNotificationAuditLog).to receive(:create!)
          .with(notification_id:, reference:, status:, payload: params)

        post(:create, params:, as: :json)

        expect(response).to have_http_status(:ok)

        res = JSON.parse(response.body)
        expect(res['message']).to eq 'success'
      end
    end

    context 'the record failed to save' do
      before do
        expect(DecisionReviewNotificationAuditLog).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)
      end

      it 'returns failed' do
        post(:create, params:, as: :json)

        expect(response).to have_http_status(:ok)

        res = JSON.parse(response.body)
        expect(res['message']).to eq 'failed'
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

  describe 'feature flag is disabled' do
    before do
      Flipper.disable :nod_callbacks_endpoint
    end

    it 'returns a 404 error code' do
      request.headers['Authorization'] = "Bearer #{Settings.nod_vanotify_status_callback.bearer_token}"
      post(:create, params:, as: :json)

      expect(response).to have_http_status(:not_found)
    end
  end
end
