# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::DecisionReviewNotificationCallbacksController, type: :controller do
  let(:notification_id) { SecureRandom.uuid }
  let(:reference) { "NOD-form-#{SecureRandom.uuid}" }
  let(:status) { 'delivered' }
  let(:params) do
    {
      id: notification_id,
      reference:,
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

    it 'logs use of the old controller' do
      warn_old_controller_args = {
        message: 'Calling decision reviews controller outside module',
        action: 'Notification callbacks controller'
      }
      allow(Rails.logger).to receive(:warn)
      expect(Rails.logger).to receive(:warn).with(warn_old_controller_args)
      post(:create, params:, as: :json)
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

    context 'the reference value is formatted correctly' do
      let(:tags) { ['service:board-appeal', 'function: form submission to Lighthouse'] }

      before do
        allow(StatsD).to receive(:increment)
        allow(Rails.logger).to receive(:error)
      end

      it 'sends a silent_failure_avoided statsd metric' do
        expect(StatsD).to receive(:increment).with('silent_failure_avoided', tags:)
        expect(Rails.logger).not_to receive(:error)

        post(:create, params:, as: :json)
      end

      context 'when the reference is for a secondary form' do
        let(:reference) { "SC-secondary_form-#{SecureRandom.uuid}" }
        let(:tags) { ['service:supplemental-claims', 'function: secondary_form submission to Lighthouse'] }

        it 'sends a silent_failure_avoided statsd metric' do
          expect(StatsD).to receive(:increment).with('silent_failure_avoided', tags:)
          expect(Rails.logger).not_to receive(:error)

          post(:create, params:, as: :json)
        end
      end
    end

    context 'the reference appeal_type is invalid' do
      let(:reference) { 'APPEALTYPE-form-submitted-appeal-uuid' }
      let(:logged_params) { { reference:, message: 'key not found: "APPEALTYPE"' } }

      before do
        allow(StatsD).to receive(:increment)
        allow(Rails.logger).to receive(:error)
      end

      it 'logs an error and does not send a silent_failure_avoided statsd metric' do
        expect(StatsD).not_to receive(:increment).with('silent_failure_avoided', tags: anything)
        expect(Rails.logger).to receive(:error).with('Failed to send silent_failure_avoided metric',
                                                     params: logged_params)

        post(:create, params:, as: :json)
      end
    end

    context 'the reference function_type is invalid' do
      let(:reference) { 'HLR-function_type-submitted-appeal-uuid' }
      let(:logged_params) { { reference:, message: 'Invalid function_type' } }

      before do
        allow(StatsD).to receive(:increment)
        allow(Rails.logger).to receive(:error)
      end

      it 'logs an error and does not send a silent_failure_avoided statsd metric' do
        expect(StatsD).not_to receive(:increment).with('silent_failure_avoided', tags: anything)
        expect(Rails.logger).to receive(:error).with('Failed to send silent_failure_avoided metric',
                                                     params: logged_params)

        post(:create, params:, as: :json)
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
