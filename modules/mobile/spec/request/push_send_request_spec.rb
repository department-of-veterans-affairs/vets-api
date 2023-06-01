# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'push send', type: :request do
  include JsonSchemaMatchers
  before { iam_sign_in }

  let(:json_body_headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }

  describe 'POST /mobile/v0/push/send' do
    context 'with with valid request body' do
      let(:params) do
        {
          appName: 'va_mobile_app',
          templateId: '0EF7C8C9390847D7B3B521426EFF5814',
          personalization: {
            '%APPOINTMENT_DATE%': 'DEC 14',
            '%APPOINTMENT_TIME%': '10:00'
          }
        }
      end

      it 'returns 200 and empty json' do
        VCR.use_cassette('vetext/send_success', match_requests_on: [:body]) do
          post '/mobile/v0/push/send', headers: iam_headers(json_body_headers), params: params.to_json
          expect(response).to have_http_status(:ok)
          expect(response.body).to eq('{}')
        end
      end
    end

    context 'with invalid template id' do
      let(:params) do
        {
          appName: 'va_mobile_app',
          templateId: 'bad_id',
          personalization: {
            '%APPOINTMENT_DATE%': 'DEC 14',
            '%APPOINTMENT_TIME%': '10:00'
          }
        }
      end

      it 'returns bad request and error' do
        VCR.use_cassette('vetext/send_bad_request') do
          post '/mobile/v0/push/send', headers: iam_headers(json_body_headers), params: params.to_json
          expect(response).to have_http_status(:bad_request)
          expect(response.body).to match_json_schema('errors')
        end
      end
    end

    context 'when causing vetext internal server error ' do
      let(:params) do
        {
          appName: 'va_mobile_app',
          templateId: '0EF7C8C9390847D7B3B521426EFF5814',
          personalization: {
            '%APPOINTMENT_DATE%': 'DEC 14',
            '%APPOINTMENT_TIME%': '10:00'
          }
        }
      end

      it 'returns bad gateway and error' do
        VCR.use_cassette('vetext/send_internal_server_error') do
          post '/mobile/v0/push/send', headers: iam_headers(json_body_headers), params: params.to_json
          expect(response).to have_http_status(:bad_gateway)
          expect(response.body).to match_json_schema('errors')
        end
      end
    end

    context 'bad app name' do
      let(:params) do
        {
          appName: 'bad_name',
          templateId: '0EF7C8C9390847D7B3B521426EFF5814',
          personalization: {
            '%APPOINTMENT_DATE%': 'DEC 14',
            '%APPOINTMENT_TIME%': '10:00'
          }
        }
      end

      it 'returns not found and error' do
        post '/mobile/v0/push/send', headers: iam_headers(json_body_headers), params: params.to_json
        expect(response).to have_http_status(:not_found)
        expect(response.body).to match_json_schema('errors')
      end
    end
  end
end
