# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'claims and appeals overview', type: :request do
  include JsonSchemaMatchers

  describe 'GET /v0/claims-and-appeals-overview' do
    describe '#index (all user claims) is polled' do
      before { iam_sign_in }

      it 'and a result that matches our schema is successfully returned with the 200 status ' do
        VCR.use_cassette('evss/claims/claims') do
          VCR.use_cassette('caseflow/appeals') do
            get '/mobile/v0/claims-and-appeals-overview', headers: iam_headers
            expect(response).to have_http_status(:ok)
            # check a couple entries to make sure the data is correct
            parsed_response_contents = response.parsed_body.dig('data')
            expect(parsed_response_contents[0].dig('type')).to eq('claim')
            expect(parsed_response_contents.last.dig('type')).to eq('appeal')
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

    describe '#index is polled' do
      before { iam_sign_in }

      it 'and claims service fails, but appeals succeeds' do
        VCR.use_cassette('evss/claims/claims_with_errors') do
          VCR.use_cassette('caseflow/appeals') do
            get '/mobile/v0/claims-and-appeals-overview', headers: iam_headers
            expect(response).to have_http_status(:multi_status)
            expect(response.parsed_body.dig('meta', 'errors').length).to eq(1)
            expect(response.parsed_body.dig('meta', 'errors')[0]['service']).to eq('claims')
            expect(response.body).to match_json_schema('claims_and_appeals_overview_response')
          end
        end
      end

      it 'and appeals service fails, but claims succeeds' do
        VCR.use_cassette('evss/claims/claims') do
          VCR.use_cassette('caseflow/server_error') do
            get '/mobile/v0/claims-and-appeals-overview', headers: iam_headers
            expect(response).to have_http_status(:multi_status)
            expect(response.parsed_body.dig('meta', 'errors').length).to eq(1)
            expect(response.parsed_body.dig('meta', 'errors')[0]['service']).to eq('appeals')
            expect(response.body).to match_json_schema('claims_and_appeals_overview_response')
          end
        end
      end

      it 'both fail in upstream service' do
        VCR.use_cassette('evss/claims/claims_with_errors') do
          VCR.use_cassette('caseflow/server_error') do
            get '/mobile/v0/claims-and-appeals-overview', headers: iam_headers
            expect(response).to have_http_status(:bad_gateway)
            expect(response.parsed_body.dig('meta', 'errors').length).to eq(2)
            expect(response.parsed_body.dig('meta', 'errors')[0]['service']).to eq('claims')
            expect(response.parsed_body.dig('meta', 'errors')[1]['service']).to eq('appeals')
            expect(response.body).to match_json_schema('claims_and_appeals_overview_response')
          end
        end
      end
    end

    describe '#index is polled without user sign in' do
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
