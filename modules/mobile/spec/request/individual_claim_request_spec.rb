# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'individual claim', type: :request do
  include JsonSchemaMatchers

  describe 'GET /v0/claim/:id' do
    before do
      Flipper.disable(:mobile_lighthouse_claims)
      iam_sign_in
      FactoryBot.create(:evss_claim, id: 1, evss_id: 600_117_255, user_uuid: '3097e489-ad75-5746-ab1a-e0aabc1b426a')
      FactoryBot.create(:evss_claim, id: 2, evss_id: 111_222_333, user_uuid: '1234567890')
    end

    context 'when the claim is found' do
      it 'matches our schema is successfully returned with the 200 status ',
         run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
        VCR.use_cassette('evss/claims/claim_with_docs') do
          get '/mobile/v0/claim/600117255', headers: iam_headers
          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'with a non-existent claim' do
      it 'returns a 404 with an error ',
         run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
        VCR.use_cassette('evss/claims/claim_with_docs') do
          get '/mobile/v0/claim/2222222', headers: iam_headers
          expect(response).to have_http_status(:not_found)
          expect(response.body).to match_json_schema('evss_errors')
        end
      end
    end

    context 'when attempting to access another users claim' do
      it 'returns a 404 with an error ',
         run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
        VCR.use_cassette('evss/claims/claim_with_docs') do
          get '/mobile/v0/claim/111222333', headers: iam_headers
          expect(response).to have_http_status(:not_found)
          expect(response.body).to match_json_schema('evss_errors')
        end
      end
    end

    context 'when evss returns a failure message' do
      it 'returns a 502 response', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
        VCR.use_cassette('evss/claims/claim_doc_with_errors') do
          get '/mobile/v0/claim/600117255', headers: iam_headers
          expect(response).to have_http_status(:bad_gateway)
          expect(response.body).to match_json_schema('errors')
        end
      end
    end
  end
end
