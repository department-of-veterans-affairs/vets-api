# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/sis_session_helper'

RSpec.describe 'claims decision request', type: :request do
  describe 'GET /v0/claim/:id/request-decision' do
    let!(:user) { sis_user(icn: '1008596379V859838') }

    before do
      FactoryBot.create(:evss_claim, id: 1, evss_id: 600_117_255, user_uuid: user.uuid)
      Flipper.disable(:mobile_lighthouse_claims)
    end

    it 'returns jid with 202 status' do
      post '/mobile/v0/claim/600117255/request-decision', headers: sis_headers
      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body.dig('data', 'jobId')).to eq(EVSS::RequestDecision.jobs.first['jid'])
    end

    it 'returns 500 for non-existent record' do
      post '/mobile/v0/claim/3242233/request-decision', headers: sis_headers
      expect(response).to have_http_status(:internal_server_error)
    end
  end
end
