# frozen_string_literal: true

require 'rails_helper'
require 'sign_in/logingov/service'

RSpec.describe SignIn::Webhooks::LogingovController, type: :controller do
  subject(:risc_request) { post :risc, body: jwt }

  let(:jwt) { create(:logingov_risc_event_payload, :encoded) }
  let(:jwks) { create(:logingov_risc_event_jwks) }
  let(:decoded_jwt) { JWT.decode(jwt, nil, true, { algorithm: 'RS256', jwks: }).first }

  before do
    request.headers['Content-Type'] = 'application/secevent+jwt'
    request.headers['Accept'] = 'application/json'

    allow_any_instance_of(SignIn::Logingov::Service).to receive(:public_jwks).and_return(jwks)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
  end

  describe 'POST /sign_in/webhooks/logingov/risc' do
    context 'when JWT is invalid' do
      let(:expected_error_message) { 'Failed to process RISC event' }
      let(:jwt) { 'some-invalid-jwt' }

      it 'returns 401 when jwt_decode raises JWTDecodeError' do
        risc_request
        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body['error']).to include(expected_error_message)
      end
    end

    context 'when the JWT is valid' do
      before do
        allow(SignIn::Logingov::RiscEventHandler).to receive(:new).and_call_original
      end

      context 'when the RISC event is valid' do
        it 'processes the RISC event successfully' do
          risc_request
          expect(SignIn::Logingov::RiscEventHandler).to have_received(:new).with(payload: decoded_jwt)
          expect(Rails.logger).to have_received(:info).with('[SignIn][Logingov][RiscEventHandler] risc_event received',
                                                            anything)
        end
      end

      context 'when the RISC event is invalid' do
        before do
          allow_any_instance_of(SignIn::Logingov::RiscEventHandler).to receive(:perform).and_raise(
            SignIn::Errors::LogingovRiscEventHandlerError.new(message: 'Invalid RISC event')
          )
        end

        it 'returns 422 when the RISC event handler raises an error' do
          risc_request
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.parsed_body['error']).to include('Failed to process RISC event')
          expect(Rails.logger).to have_received(:error).with('[SignIn][Webhooks][LogingovController] risc error',
                                                             error_message: 'Invalid RISC event')
        end
      end
    end
  end
end
