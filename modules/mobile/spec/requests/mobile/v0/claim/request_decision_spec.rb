# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::Claim::RequestDecision', :skip_json_api_validation, type: :request do
  describe 'GET /v0/claim/:id/request-decision' do
    let!(:user) { sis_user(icn: '1008596379V859838') }

    before do
      token = 'abcdefghijklmnop'
      allow_any_instance_of(BenefitsClaims::Configuration).to receive(:access_token).and_return(token)
      Flipper.enable_actor(:mobile_lighthouse_request_decision, user)
    end

    after { Flipper.disable_actor(:mobile_lighthouse_request_decision, user) }

    it 'returns success with 202 status' do
      VCR.use_cassette('mobile/lighthouse_claims/request_decision/200_response') do
        post '/mobile/v0/claim/600397108/request-decision', headers: sis_headers
      end
      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body.dig('data', 'jobId')).to eq('success')
    end

    it 'returns failure with 202 status' do
      VCR.use_cassette('mobile/lighthouse_claims/request_decision/200_failure_response') do
        post '/mobile/v0/claim/600397108/request-decision', headers: sis_headers
      end
      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body.dig('data', 'jobId')).to eq('failure')
    end

    it 'returns 404 for non-existent record' do
      VCR.use_cassette('mobile/lighthouse_claims/request_decision/404_response') do
        post '/mobile/v0/claim/600397108/request-decision', headers: sis_headers
      end
      expect(response).to have_http_status(:not_found)
    end
  end
end
