# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'appointment preferences', type: :request do
  include JsonSchemaMatchers

  before do
    Flipper.enable('va_online_scheduling')
    allow_any_instance_of(IAMUser).to receive(:icn).and_return('24811694708759028')
    iam_sign_in(build(:iam_user))
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  describe 'GET /appointments/preferences', :aggregate_failures do
    it 'returns a 200 with the correct schema' do
      VCR.use_cassette('mobile/appointments/get_preferences', match_requests_on: %i[method uri]) do
        get '/mobile/v0/appointments/preferences', headers: iam_headers

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
        put '/mobile/v0/appointments/preferences', headers: iam_headers, params: request_body

        expect(response).to have_http_status(:ok)
        expect(response.body).to match_json_schema('appointment_preferences')
      end
    end

    context 'when only required fields are included in params' do
      it 'returns a 200 code' do
        VCR.use_cassette('mobile/appointments/put_preferences_minimal_payload', match_requests_on: %i[method uri]) do
          put '/mobile/v0/appointments/preferences', headers: iam_headers, params: request_body

          expect(response).to have_http_status(:ok)
          expect(response.body).to match_json_schema('appointment_preferences')
        end
      end
    end
  end
end
