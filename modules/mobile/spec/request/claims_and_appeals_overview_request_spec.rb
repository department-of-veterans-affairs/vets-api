# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'claims and appeals overview', type: :request do
  include JsonSchemaMatchers
  before { iam_sign_in }

  describe 'GET /v0/claims-and-appeals-overview' do
    context '#index (all user claims) is polled' do
      it 'uses camel-inflection and returns empty result, kicks off job, returns full result when job is completed' do
        VCR.use_cassette('evss/claims/claims') do
          VCR.use_cassette('caseflow/appeals') do
            get '/mobile/v0/claims-and-appeals-overview', headers: iam_headers
            expect(response).to have_http_status(:ok)
            expect(response.body).to match_json_schema('claims_and_appeals_overview_response')
          end
        end
      end
    end
  end
end
