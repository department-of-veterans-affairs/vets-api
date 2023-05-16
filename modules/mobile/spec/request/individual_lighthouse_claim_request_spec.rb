# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'
require 'lighthouse/benefits_claims/configuration'
require 'lighthouse/benefits_claims/service'

RSpec.describe 'lighthouse individual claim', type: :request do
  include JsonSchemaMatchers

  before(:all) do
    @original_cassette_dir = VCR.configure(&:cassette_library_dir)
    VCR.configure { |c| c.cassette_library_dir = 'modules/mobile/spec/support/vcr_cassettes' }
  end

  after(:all) { VCR.configure { |c| c.cassette_library_dir = @original_cassette_dir } }

  describe 'GET /v0/claim/:id with lighthouse upstream service' do
    before do
      token = 'abcdefghijklmnop'
      allow_any_instance_of(Mobile::V0::LighthouseClaims::Configuration).to receive(:access_token).and_return(token)
      Flipper.enable(:mobile_lighthouse_claims)
      iam_sign_in
    end

    after { Flipper.disable(:mobile_lighthouse_claims) }

    context 'when the claim is found' do
      it 'matches our schema is successfully returned with the 200 status',
         run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
        VCR.use_cassette('lighthouse_claims/show/200_response') do
          get '/mobile/v0/claim/600117255', headers: iam_headers
          expect(response).to have_http_status(:ok)
          expect(response.body).to match_json_schema('individual_claim', strict: true)
        end
      end
    end

    context 'with a non-existent claim' do
      it 'returns a 404 with an error',
         run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
        VCR.use_cassette('lighthouse_claims/show/404_response') do
          get '/mobile/v0/claim/60038334', headers: iam_headers

          expect(response).to have_http_status(:not_found)
          expect(response.parsed_body).to eq({ 'errors' => [{ 'title' => 'Resource not found',
                                                              'detail' => 'Resource not found',
                                                              'code' => '404', 'status' => '404' }] })
        end
      end
    end
  end
end
