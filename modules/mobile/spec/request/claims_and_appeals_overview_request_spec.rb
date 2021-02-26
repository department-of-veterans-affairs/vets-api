# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'claims and appeals overview', type: :request do
  include JsonSchemaMatchers

  before(:all) do
    @original_cassette_dir = VCR.configure(&:cassette_library_dir)
    VCR.configure { |c| c.cassette_library_dir = 'modules/mobile/spec/support/vcr_cassettes' }
  end

  after(:all) { VCR.configure { |c| c.cassette_library_dir = @original_cassette_dir } }

  describe 'GET /v0/claims-and-appeals-overview' do
    describe '#index (all user claims) is polled' do
      before { iam_sign_in }

      it 'and a result that matches our schema is successfully returned with the 200 status ' do
        VCR.use_cassette('claims/claims') do
          VCR.use_cassette('appeals/appeals') do
            get '/mobile/v0/claims-and-appeals-overview', headers: iam_headers
            expect(response).to have_http_status(:ok)
            # check a couple entries to make sure the data is correct
            parsed_response_contents = response.parsed_body.dig('data')
            open_claim = parsed_response_contents.select { |entry| entry.dig('id') == '600114693' }[0]
            closed_claim = parsed_response_contents.select { |entry| entry.dig('id') == '600023098' }[0]
            open_appeal = parsed_response_contents.select { |entry| entry.dig('id') == '3294289' }[0]
            closed_appeal = parsed_response_contents.select { |entry| entry.dig('id') == '2348605' }[0]
            expect(open_claim.dig('attributes', 'completed')).to eq(false)
            expect(closed_claim.dig('attributes', 'completed')).to eq(true)
            expect(open_appeal.dig('attributes', 'completed')).to eq(false)
            expect(closed_appeal.dig('attributes', 'completed')).to eq(true)
            expect(open_claim.dig('type')).to eq('claim')
            expect(closed_claim.dig('type')).to eq('claim')
            expect(open_appeal.dig('type')).to eq('appeal')
            expect(closed_appeal.dig('type')).to eq('appeal')
            expect(response.body).to match_json_schema('claims_and_appeals_overview_response')
          end
        end
      end

      it 'and invalid headers return a 401 status' do
        VCR.use_cassette('claims/claims') do
          VCR.use_cassette('appeals/appeals') do
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
        VCR.use_cassette('claims/claims_with_errors') do
          VCR.use_cassette('appeals/appeals') do
            get '/mobile/v0/claims-and-appeals-overview', headers: iam_headers
            parsed_response_contents = response.parsed_body.dig('data')
            expect(parsed_response_contents[0].dig('type')).to eq('appeal')
            expect(parsed_response_contents.last.dig('type')).to eq('appeal')
            expect(response).to have_http_status(:multi_status)
            expect(response.parsed_body.dig('meta', 'errors').length).to eq(1)
            expect(response.parsed_body.dig('meta', 'errors')[0]['service']).to eq('claims')
            open_appeal = parsed_response_contents.select { |entry| entry.dig('id') == '3294289' }[0]
            closed_appeal = parsed_response_contents.select { |entry| entry.dig('id') == '2348605' }[0]
            expect(open_appeal.dig('attributes', 'completed')).to eq(false)
            expect(closed_appeal.dig('attributes', 'completed')).to eq(true)
            expect(open_appeal.dig('type')).to eq('appeal')
            expect(closed_appeal.dig('type')).to eq('appeal')
            expect(response.body).to match_json_schema('claims_and_appeals_overview_response')
          end
        end
      end

      it 'and appeals service fails, but claims succeeds' do
        VCR.use_cassette('claims/claims') do
          VCR.use_cassette('appeals/server_error') do
            get '/mobile/v0/claims-and-appeals-overview', headers: iam_headers
            expect(response).to have_http_status(:multi_status)
            parsed_response_contents = response.parsed_body.dig('data')
            expect(parsed_response_contents[0].dig('type')).to eq('claim')
            expect(parsed_response_contents.last.dig('type')).to eq('claim')
            expect(response.parsed_body.dig('meta', 'errors').length).to eq(1)
            expect(response.parsed_body.dig('meta', 'errors')[0]['service']).to eq('appeals')
            open_claim = parsed_response_contents.select { |entry| entry.dig('id') == '600114693' }[0]
            closed_claim = parsed_response_contents.select { |entry| entry.dig('id') == '600023098' }[0]
            expect(open_claim.dig('attributes', 'completed')).to eq(false)
            expect(closed_claim.dig('attributes', 'completed')).to eq(true)
            expect(open_claim.dig('type')).to eq('claim')
            expect(closed_claim.dig('type')).to eq('claim')
            expect(response.body).to match_json_schema('claims_and_appeals_overview_response')
          end
        end
      end

      it 'both fail in upstream service' do
        VCR.use_cassette('claims/claims_with_errors') do
          VCR.use_cassette('appeals/server_error') do
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
        VCR.use_cassette('claims/claims') do
          VCR.use_cassette('appeals/appeals') do
            get '/mobile/v0/claims-and-appeals-overview', headers: iam_headers
            expect(response).to have_http_status(:internal_server_error)
          end
        end
      end
    end
  end
end
