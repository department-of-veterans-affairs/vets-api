# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::EventBusGatewayController, type: :controller do
  describe '#send_email' do
    let(:params) do
      {
        participant_id: '1234',
        template_id: '5678',
        personalisation: {}
      }
    end

    context 'when :event_bus_gateway_emails_enabled is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).and_call_original
        allow(Flipper).to receive(:enabled?).with(:event_bus_gateway_emails_enabled).and_return(true)
      end

      it 'invokes the email-sending job' do
        expect(EventBusGateway::LetterReadyEmailJob).to receive(:perform_async)
        post(:send_email, params:)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when :event_bus_gateway_emails_enabled is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).and_call_original
        allow(Flipper).to receive(:enabled?).with(:event_bus_gateway_emails_enabled).and_return(false)
      end

      it 'does not invoke the email-sending job' do
        expect(EventBusGateway::LetterReadyEmailJob).not_to receive(:perform_async)
        post(:send_email, params:)
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
