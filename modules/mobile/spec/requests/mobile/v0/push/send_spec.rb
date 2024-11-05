# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::Push::Send', type: :request do
  include JsonSchemaMatchers

  let!(:user) { sis_user(icn: '1008596379V859838') }

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

      it 'returns 200 and empty json', :skip_json_api_validation do
        VCR.use_cassette('vetext/send_success', match_requests_on: [:body]) do
          post '/mobile/v0/push/send', headers: sis_headers(json: true), params: params.to_json
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
          post '/mobile/v0/push/send', headers: sis_headers(json: true), params: params.to_json
          expect(response).to have_http_status(:bad_request)
          expect(response.body).to match_json_schema('errors')
        end
      end
    end

    context 'when causing vetext internal server error' do
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
          post '/mobile/v0/push/send', headers: sis_headers(json: true), params: params.to_json
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
        post '/mobile/v0/push/send', headers: sis_headers(json: true), params: params.to_json
        expect(response).to have_http_status(:not_found)
        expect(response.body).to match_json_schema('errors')
      end
    end
  end
end
