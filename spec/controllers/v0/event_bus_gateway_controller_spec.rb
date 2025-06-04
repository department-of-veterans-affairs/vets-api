# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::EventBusGatewayController, type: :request do
  include_context 'with service account authentication', 'eventbus', ['http://www.example.com/v0/event_bus_gateway/send_email'], { user_attributes: { participant_id: '1234' } }
  describe 'POST /v0/event_bus_gateway/send_email' do
    let(:params) do
      {
        template_id: '5678'
      }
    end
    context 'when :event_bus_gateway_emails_enabled is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).and_call_original
        allow(Flipper).to receive(:enabled?).with(:event_bus_gateway_emails_enabled).and_return(true)
      end

      context 'with the authentication header included' do
        it 'invokes the email-sending job' do
          expect(EventBusGateway::LetterReadyEmailJob).to receive(:perform_async).with('1234', '5678')
          post v0_event_bus_gateway_send_email_path(params:), headers: service_account_auth_header
          expect(response).to have_http_status(:ok)
        end
      end

      context 'without the authentication header' do
        it 'returns an unauthorized response' do
          post v0_event_bus_gateway_send_email_path(params:), headers: nil
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end

    context 'when :event_bus_gateway_emails_enabled is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).and_call_original
        allow(Flipper).to receive(:enabled?).with(:event_bus_gateway_emails_enabled).and_return(false)
      end

      context 'without the authentication header' do
        it 'returns an unauthorized response' do
          post v0_event_bus_gateway_send_email_path(params:), headers: nil
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'with the authentication header included' do
        it 'does not invoke the email-sending job' do
          expect(EventBusGateway::LetterReadyEmailJob).not_to receive(:perform_async)
          post v0_event_bus_gateway_send_email_path(params:), headers: service_account_auth_header
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end
end
