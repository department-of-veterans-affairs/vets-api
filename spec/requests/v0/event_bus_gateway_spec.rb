# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::EventBusGateway', type: :request do
  include_context 'with service account authentication', 'eventbus', [
    'http://www.example.com/v0/event_bus_gateway/send_email',
    'http://www.example.com/v0/event_bus_gateway/send_notifications',
    'http://www.example.com/v0/event_bus_gateway/send_push'
  ], { user_attributes: { participant_id: '1234' } }

  describe 'POST /v0/event_bus_gateway/send_email' do
    let(:params) do
      {
        template_id: '5678'
      }
    end

    context 'with the authentication header included' do
      it 'invokes the email-sending job' do
        expect(EventBusGateway::LetterReadyEmailJob).to receive(:perform_async).with('1234', '5678')
        post '/v0/event_bus_gateway/send_email', params:, headers: service_account_auth_header
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without the authentication header' do
      it 'returns an unauthorized response' do
        post '/v0/event_bus_gateway/send_email', params:, headers: nil
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /v0/event_bus_gateway/send_notifications' do
    let(:params) do
      {
        email_template_id: '5678',
        push_template_id: '9012'
      }
    end

    context 'with the authentication header included' do
      it 'invokes the notification-sending job with both templates' do
        expect(EventBusGateway::LetterReadyNotificationJob).to receive(:perform_async).with('1234', '5678', '9012')
        post '/v0/event_bus_gateway/send_notifications', params:, headers: service_account_auth_header
        expect(response).to have_http_status(:ok)
      end

      it 'invokes the notification-sending job with only email template' do
        params_email_only = { email_template_id: '5678' }
        expect(EventBusGateway::LetterReadyNotificationJob).to receive(:perform_async).with('1234', '5678', nil)
        post '/v0/event_bus_gateway/send_notifications', params: params_email_only, headers: service_account_auth_header
        expect(response).to have_http_status(:ok)
      end

      it 'invokes the notification-sending job with only push template' do
        params_push_only = { push_template_id: '9012' }
        expect(EventBusGateway::LetterReadyNotificationJob).to receive(:perform_async).with('1234', nil, '9012')
        post '/v0/event_bus_gateway/send_notifications', params: params_push_only, headers: service_account_auth_header
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without the authentication header' do
      it 'returns an unauthorized response' do
        post '/v0/event_bus_gateway/send_notifications', params:, headers: nil
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /v0/event_bus_gateway/send_push' do
    let(:params) do
      {
        template_id: '5678'
      }
    end

    context 'with the authentication header included' do
      it 'invokes the push-sending job' do
        expect(EventBusGateway::LetterReadyPushJob).to receive(:perform_async).with('1234', '5678')
        post '/v0/event_bus_gateway/send_push', params:, headers: service_account_auth_header
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without the authentication header' do
      it 'returns an unauthorized response' do
        post '/v0/event_bus_gateway/send_push', params:, headers: nil
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
