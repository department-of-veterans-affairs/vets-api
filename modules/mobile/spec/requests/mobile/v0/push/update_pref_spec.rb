# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::Push::UpdatePref', type: :request do
  include JsonSchemaMatchers
  let!(:user) { sis_user }

  describe 'PUT /mobile/v0/push/send' do
    context 'with with valid request body' do
      let(:params) do
        {
          preference: 'claim_status_updates',
          enabled: true
        }
      end

      it 'returns 200 and empty json', :skip_json_api_validation do
        VCR.use_cassette('vetext/set_preference_success') do
          put('/mobile/v0/push/prefs/8c258cbe573c462f912e7dd74585a5a9', headers: sis_headers, params:)
          expect(response).to have_http_status(:ok)
          expect(response.body).to eq('{}')
        end
      end
    end

    context 'when preference is not found' do
      let(:params) do
        {
          preference: 'claim_status_updates',
          enabled: true
        }
      end

      it 'returns bad request and error' do
        VCR.use_cassette('vetext/set_preferences_bad_request') do
          put('/mobile/v0/push/prefs/bad_id', headers: sis_headers, params:)
          expect(response).to have_http_status(:bad_request)
          expect(response.body).to match_json_schema('errors')
        end
      end
    end

    context 'when causing vetext internal server error' do
      let(:params) do
        {
          preference: 'claim_status_updates',
          enabled: true
        }
      end

      it 'returns bad gateway and error' do
        VCR.use_cassette('vetext/set_preferences_internal_server_error') do
          put('/mobile/v0/push/prefs/bad_id', headers: sis_headers, params:)
          expect(response).to have_http_status(:bad_gateway)
          expect(response.body).to match_json_schema('errors')
        end
      end
    end
  end
end
