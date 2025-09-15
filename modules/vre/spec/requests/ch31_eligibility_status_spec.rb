# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VRE::V0::Ch31EligibilityStatus', type: :request do
  include SchemaMatchers

  before { sign_in_as(user) }

  describe 'GET vre/v0/ch31_eligibility_status' do
    context 'when eligibility status available' do
      let(:user) { create(:user, icn: '1012667145V762142') }

      it 'returns 200 response' do
        VCR.use_cassette('vre/ch31_eligibility/200') do
          get '/vre/v0/ch31_eligibility_status'
          expect(response).to match_response_schema('vre/ch31_eligibility_status')
          assert_response :success
        end
      end
    end

    context 'when no icn present' do
      let(:user) { create(:user, icn: nil) }

      it 'raises ParameterMissing error' do
        get '/vre/v0/ch31_eligibility_status'
        expect(response).to have_http_status(:bad_request)
        message = JSON.parse(response.body)['errors'].first['detail']
        expect(message).to eq('The required parameter "ICN", is missing')
      end
    end

    context 'when eligibility not found for user' do
      let(:user) { create(:user, icn: '1234') }

      it 'returns 404 response' do
        VCR.use_cassette('vre/ch31_eligibility/404') do
          get '/vre/v0/ch31_eligibility_status'
          expect(response).to have_http_status(:not_found)
          message = JSON.parse(response.body)['errors'].first['detail']
          expect(message).to eq('Not Found')
        end
      end
    end

    context 'when upstream service is unavailable' do
      let(:user) { create(:user, icn: '1012667145V762142') }

      it 'returns 503 response' do
        VCR.use_cassette('vre/ch31_eligibility/500') do
          get '/vre/v0/ch31_eligibility_status'
          expect(response).to have_http_status(:service_unavailable)
          message = JSON.parse(response.body)['errors'].first['detail']
          expect(message).to eq('Service Unavailable')
        end
      end
    end
  end
end
