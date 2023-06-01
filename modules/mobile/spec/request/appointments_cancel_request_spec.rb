# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'appointments', type: :request do
  include JsonSchemaMatchers

  before do
    allow_any_instance_of(IAMUser).to receive(:icn).and_return('24811694708759028')
    iam_sign_in(build(:iam_user))
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  describe 'PUT /mobile/v0/appointments/cancel', :aggregate_failures do
    let(:cancel_id) { '70060' }

    it 'returns a no content code' do
      VCR.use_cassette('mobile/appointments/VAOS_v2/cancel_appointment_200', match_requests_on: %i[method uri]) do
        put "/mobile/v0/appointments/cancel/#{cancel_id}", params: nil, headers: iam_headers

        expect(response).to have_http_status(:no_content)
        expect(response.body).to be_an_instance_of(String).and be_empty
      end
    end

    context 'when the appointment cannot be found' do
      it 'returns a 400 code' do
        VCR.use_cassette('mobile/appointments/VAOS_v2/cancel_appointment_400', match_requests_on: %i[method uri]) do
          put "/mobile/v0/appointments/cancel/#{cancel_id}", params: nil, headers: iam_headers

          expect(response.status).to eq(400)
          expect(response.parsed_body.dig('errors', 0, 'code')).to eq('VAOS_400')

          error_message = JSON.parse(response.parsed_body.dig('errors', 0, 'source', 'vamfBody'))['message']
          expect(error_message).to eq('appointment may not be cancelled')
        end
      end
    end

    context 'when the backend service cannot handle the request' do
      it 'returns a 502 code' do
        VCR.use_cassette('mobile/appointments/VAOS_v2/cancel_appointment_500', match_requests_on: %i[method uri]) do
          put "/mobile/v0/appointments/cancel/#{cancel_id}", params: nil, headers: iam_headers
          expect(response.status).to eq(502)
          expect(JSON.parse(response.body)['errors'][0]['code']).to eq('VAOS_502')

          error_message = JSON.parse(response.parsed_body.dig('errors', 0, 'source', 'vamfBody'))['message']
          expect(error_message).to eq('failed to cancel appointment')
        end
      end
    end
  end
end
