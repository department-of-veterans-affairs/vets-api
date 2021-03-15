# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'push send', type: :request do
  include JsonSchemaMatchers
  before { iam_sign_in }

  describe 'POST /mobile/v0/push/send' do
    context 'with with valid request body' do
      let(:params) do
        {
            endpointSid: "8c258cbe573c462f912e7dd74585a5a9",
            templateId: "0EF7C8C9390847D7B3B521426EFF5814",
            personalization: {
                "%APPOINTMENT_DATE%": "DEC 14",
                "%APPOINTMENT_TIME%": "10:00"
            }
        }
      end
      it 'returns 200 and empty json' do
        VCR.use_cassette('vetext/send_success') do
          post '/mobile/v0/push/send', headers: iam_headers, params: params
          expect(response).to have_http_status(:ok)
          expect(response.body).to eq("{}")
        end
      end
    end

    context 'with with invalid endpointSid' do
      let(:params) do
        {
            endpointSid: "8c258cbe573c462f912e7dd74585a5a9",
            templateId: "0EF7C8C9390847D7B3B521426EFF5814",
            personalization: {
                "%APPOINTMENT_DATE%": "DEC 14",
                "%APPOINTMENT_TIME%": "10:00"
            }
        }
      end
      it 'returns 200 and empty json' do
        VCR.use_cassette('vetext/send_bad_request') do
          post '/mobile/v0/push/send', headers: iam_headers, params: params
          expect(response).to have_http_status(:bad_request)
          expect(response.body).to match_json_schema('errors')
        end
      end
    end
  end
end
