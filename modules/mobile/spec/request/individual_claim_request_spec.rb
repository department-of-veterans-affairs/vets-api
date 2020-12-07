# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'individual claim', type: :request do
  include JsonSchemaMatchers

  describe 'GET /v0/claim/:id' do
    before { iam_sign_in }
    let!(:claim) do
      FactoryBot.create(:evss_claim, id: 1, evss_id: 600_117_255,
                        user_uuid: '3097e489-ad75-5746-ab1a-e0aabc1b426a')
    end

    it 'and a result that matches our schema is successfully returned with the 200 status ', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
      VCR.use_cassette('evss/claims/claim', match_requests_on: %i[uri method body]) do
        get '/mobile/v0/claim/600117255', headers: iam_headers
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
