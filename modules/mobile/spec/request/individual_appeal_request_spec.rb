# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'individual appeal', type: :request do
  include JsonSchemaMatchers

  describe 'GET /v0/appeal/:id' do
    before { iam_sign_in }

    it 'and a result that matches our schema is successfully returned with the 200 status ' do
      VCR.use_cassette('caseflow/appeals') do
        get '/mobile/v0/appeal/3294289', headers: iam_headers
        expect(response).to have_http_status(:ok)
      end
    end

    it 'and attempting to access a nonexistant appeal returns a 404 wtih an error ' do
      VCR.use_cassette('caseflow/appeals') do
        get '/mobile/v0/appeal/1234567', headers: iam_headers
        expect(response).to have_http_status(:not_found)
        expect(response.body).to match_json_schema('evss_errors')
      end
    end
  end
end
