# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VRE::V0::Ch31CaseDetails', type: :request do
  include SchemaMatchers

  before { sign_in_as(user) }

  describe 'GET vre/v0/ch31_case_details' do
    context 'when case details available' do
      let(:user) { create(:user, icn: '1012662125V786396') }

      it 'returns 200 response' do
        VCR.use_cassette('vre/ch31_case_details/200') do
          get '/vre/v0/ch31_case_details'
          expect(response).to match_response_schema('vre/ch31_case_details')
          assert_response :success
        end
      end
    end

    context 'when no icn present' do
      let(:user) { create(:user, icn: nil) }

      it 'raises ParameterMissing error' do
        get '/vre/v0/ch31_case_details'
        expect(response).to have_http_status(:bad_request)
        message = JSON.parse(response.body)['errors'].first['detail']
        expect(message).to eq('The required parameter "ICN", is missing')
      end
    end

    context 'when case details forbidden for user' do
      let(:user) { create(:user, icn: '1234') }

      it 'returns 403 response' do
        VCR.use_cassette('vre/ch31_case_details/403') do
          get '/vre/v0/ch31_case_details'
          expect(response).to have_http_status(:forbidden)
          message = JSON.parse(response.body)['errors'].first['detail']
          expect(message).to eq('Forbidden')
        end
      end
    end

    context 'when upstream service is not available' do
      let(:user) { create(:user, icn: '1012667145V762142') }

      it 'returns 503 response' do
        VCR.use_cassette('vre/ch31_case_details/500') do
          get '/vre/v0/ch31_case_details'
          expect(response).to have_http_status(:service_unavailable)
          message = JSON.parse(response.body)['errors'].first['detail']
          expect(message).to eq('Service Unavailable')
        end
      end
    end
  end
end
