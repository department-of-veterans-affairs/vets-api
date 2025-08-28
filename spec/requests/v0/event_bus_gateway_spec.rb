# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::EventBusGateway', type: :request do
  include_context 'with service account authentication', 'eventbus', ['http://www.example.com/v0/event_bus_gateway/send_email'], { user_attributes: { participant_id: '1234' } }
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
end
