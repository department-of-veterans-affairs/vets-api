# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'

RSpec.describe 'claims decision request', type: :request do
  describe 'GET /v0/claim/:id/request-decision' do
    before do
      iam_sign_in
      FactoryBot.create(:evss_claim, id: 1, evss_id: 600_117_255, user_uuid: '3097e489-ad75-5746-ab1a-e0aabc1b426a')
    end

    it 'returns jid with 202 status' do
      post '/mobile/v0/claim/600117255/request-decision', headers: iam_headers
      expect(response.status).to eq(202)
      expect(response.parsed_body.dig('data', 'jobId')).to eq(EVSS::RequestDecision.jobs.first['jid'])
    end

    it 'returns 500 for non-existent record' do
      post '/mobile/v0/claim/3242233/request-decision', headers: iam_headers
      expect(response.status).to eq(500)
    end
  end
end
