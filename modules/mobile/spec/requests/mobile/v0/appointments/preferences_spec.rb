# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::Appointments::Preferences', type: :request do
  include JsonSchemaMatchers

  let!(:user) { sis_user(icn: '24811694708759028') }

  before do
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  describe 'GET /appointments/preferences', :aggregate_failures do
    it 'returns a 200 with the correct schema' do
      VCR.use_cassette('mobile/appointments/get_preferences', match_requests_on: %i[method uri]) do
        get '/mobile/v0/appointments/preferences', headers: sis_headers

        expect(response).to have_http_status(:ok)
        expect(response.body).to match_json_schema('appointment_preferences')
      end
    end
  end

  describe 'PUT /appointments/preferences', :aggregate_failures do
    let(:request_body) do
      {
        notification_frequency: 'Each new message',
        email_allowed: true,
        email_address: 'abraham.lincoln@va.gov',
        text_msg_allowed: false,
        text_msg_ph_number: ''
      }
    end

    let(:minimal_request_body) do
      {
        notification_frequency: 'Each new message'
      }
    end

    it 'returns a 200 code' do
      VCR.use_cassette('mobile/appointments/put_preferences', match_requests_on: %i[method uri]) do
        put '/mobile/v0/appointments/preferences', headers: sis_headers, params: request_body

        expect(response).to have_http_status(:ok)
        expect(response.body).to match_json_schema('appointment_preferences')
      end
    end

    context 'when only required fields are included in params' do
      it 'returns a 200 code' do
        VCR.use_cassette('mobile/appointments/put_preferences_minimal_payload', match_requests_on: %i[method uri]) do
          put '/mobile/v0/appointments/preferences', headers: sis_headers, params: request_body

          expect(response).to have_http_status(:ok)
          expect(response.body).to match_json_schema('appointment_preferences')
        end
      end
    end
  end
end
