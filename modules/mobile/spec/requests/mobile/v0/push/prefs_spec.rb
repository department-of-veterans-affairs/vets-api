# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::Push::Prefs', type: :request do
  include JsonSchemaMatchers
  let!(:user) { sis_user }

  describe 'GET /mobile/v0/push/prefs/{endpointSid}' do
    context 'with a valid endpointSid' do
      let!(:vetext_response) do
        [
          {
            auto_opt_in: false,
            endpoint_sid: '8c258cbe573c462f912e7dd74585a5a9',
            preference_name: 'Appointment reminders',
            preference_id: 'appointment_reminders',
            value: true
          },
          {
            auto_opt_in: false,
            endpoint_sid: '8c258cbe573c462f912e7dd74585a5a9',
            preference_name: 'Benefits claims and decision reviews',
            preference_id: 'claim_status_updates',
            value: true
          }
        ]
      end

      let(:vetext_service_double) { instance_double(VEText::Service) }

      before do
        allow(VEText::Service).to receive(:new).and_return(vetext_service_double)
        allow(vetext_service_double).to receive(:get_preferences).with('8c258cbe573c462f912e7dd74585a5a9').and_return(
          Faraday::Response.new(
            status: 200, body: vetext_response
          )
        )
      end

      context 'when :event_bus_gateway_letter_ready_push_notifications is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:event_bus_gateway_letter_ready_push_notifications,
                                                    instance_of(Flipper::Actor)).and_return(true)
        end

        it 'matches the get_prefs schema' do
          get '/mobile/v0/push/prefs/8c258cbe573c462f912e7dd74585a5a9', headers: sis_headers
          expect(response).to have_http_status(:ok)
          expect(response.body).to match_json_schema('get_prefs')
          expect(response.body).to include('claim_status_updates')
        end
      end

      context 'when :event_bus_gateway_letter_ready_push_notifications is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:event_bus_gateway_letter_ready_push_notifications,
                                                    instance_of(Flipper::Actor)).and_return(false)
        end

        it 'matches the get_prefs schema' do
          get '/mobile/v0/push/prefs/8c258cbe573c462f912e7dd74585a5a9', headers: sis_headers
          expect(response).to have_http_status(:ok)
          expect(response.body).to match_json_schema('get_prefs')
          expect(response.body).not_to include('claim_status_updates')
        end
      end
    end

    context 'with a invalid endpointSid' do
      it 'returns bad request and errors' do
        VCR.use_cassette('vetext/get_preferences_bad_request') do
          get '/mobile/v0/push/prefs/8c258cbe573c462f912e7dd74585a5a9', headers: sis_headers
          expect(response).to have_http_status(:bad_request)
          expect(response.body).to match_json_schema('errors')
        end
      end
    end

    context 'when causing vetext internal server error' do
      it 'returns bad gateway and errors' do
        VCR.use_cassette('vetext/get_preferences_internal_server_error') do
          get '/mobile/v0/push/prefs/8c258cbe573c462f912e7dd74585a5a9', headers: sis_headers
          expect(response).to have_http_status(:bad_gateway)
          expect(response.body).to match_json_schema('errors')
        end
      end
    end
  end
end
