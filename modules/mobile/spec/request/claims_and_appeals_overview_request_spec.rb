# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'claims and appeals overview', type: :request do
  include JsonSchemaMatchers

  describe 'GET /v0/claims-and-appeals-overview' do
    context '#index (all user claims) is polled' do
      before { iam_sign_in }
      it 'and a result that matches our schema is successfully returned with the 200 status ' do
        VCR.use_cassette('evss/claims/claims') do
          VCR.use_cassette('caseflow/appeals') do
            get '/mobile/v0/claims-and-appeals-overview', headers: iam_headers
            expect(response).to have_http_status(:ok)
            expect(response.body).to match_json_schema('claims_and_appeals_overview_response')
          end
        end
      end

      it 'and invalid headers return a 401 status' do
        VCR.use_cassette('evss/claims/claims') do
          VCR.use_cassette('caseflow/appeals') do
            get '/mobile/v0/claims-and-appeals-overview'
            expect(response).to have_http_status(:unauthorized)
            expect(response.body).to match_json_schema('evss_errors')
          end
        end
      end
    end

    context '#index is polled without user sign in' do
      it 'and not user returns a 500 status' do
        VCR.use_cassette('evss/claims/claims') do
          VCR.use_cassette('caseflow/appeals') do
            get '/mobile/v0/claims-and-appeals-overview', headers: iam_headers
            expect(response).to have_http_status(:internal_server_error)
          end
        end
      end
    end
    
  end
end
