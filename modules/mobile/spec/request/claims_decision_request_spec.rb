# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'

RSpec.describe 'lighthouse claims decision request', type: :request do
  describe 'GET /v0/claim/:id/request-decision' do
    before do
      token = 'abcdefghijklmnop'
      allow_any_instance_of(BenefitsClaims::Configuration).to receive(:access_token).and_return(token)
      user = build(:iam_user)
      iam_sign_in(user)
      Flipper.enable(:mobile_lighthouse_claims, user)
    end

    after { Flipper.disable(:mobile_lighthouse_claims) }

    it 'returns jid with 202 status' do
      VCR.use_cassette('mobile/lighthouse_claims/request_decision/200_response') do
        post '/mobile/v0/claim/600397108/request-decision', headers: iam_headers
      end
      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body.dig('data', 'jobId')).to eq({ 'success' => true })
    end

    it 'returns 404 for non-existent record' do
      VCR.use_cassette('mobile/lighthouse_claims/request_decision/404_response') do
        post '/mobile/v0/claim/600397108/request-decision', headers: iam_headers
      end
      expect(response).to have_http_status(:not_found)
    end
  end
end
