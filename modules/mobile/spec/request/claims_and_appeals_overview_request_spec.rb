# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'claims and appeals overview', type: :request do
  include JsonSchemaMatchers

  describe 'GET /v0/claims-and-appeals-overview' do
    describe '#index (all user claims) is polled' do
      before { iam_sign_in }

      let(:successful_response_item_zero) do
        {
          'id' => '600118851',
          'type' => 'claim',
          'attributes' => {
            'subtype' => 'Compensation',
            'completed' => false,
            'dateFiled' => '2017-12-08'
          }
        }
      end

      let(:successful_response_item_twenty) do
        {
          'id' => '600100167',
          'type' => 'claim',
          'attributes' => {
            'subtype' => 'Dependency',
            'completed' => true,
            'dateFiled' => '2017-04-21'
          }
        }
      end

      let(:successful_response_last_item) do
        {
          'id' => '1196201',
          'type' => 'appeal',
          'attributes' => {
            'subtype' => 'legacyAppeal',
            'completed' => true,
            'dateFiled' => '2003-01-06',
            'updatedAt' => '2018-01-19T10:20:42-05:00'
          }
        }
      end

      it 'and a result that matches our schema is successfully returned with the 200 status ' do
        VCR.use_cassette('evss/claims/claims') do
          VCR.use_cassette('caseflow/appeals') do
            get '/mobile/v0/claims-and-appeals-overview', headers: iam_headers
            expect(response).to have_http_status(:ok)
            # check a couple entries to make sure the data is correct
            parsed_response_contents = JSON.parse(response.body)['data']['attributes']['claimsAndAppeals']
            expect(parsed_response_contents[0]).to eq(successful_response_item_zero)
            expect(parsed_response_contents[20]).to eq(successful_response_item_twenty)
            expect(parsed_response_contents.last).to eq(successful_response_last_item)
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

      let(:claims_failure_response_item_zero) do
        {
          'id' => '2348605',
          'type' => 'appeal',
          'attributes' => {
            'subtype' => 'legacyAppeal',
            'completed' => true,
            'dateFiled' => '2010-09-17',
            'updatedAt' => '2018-01-19T10:20:42-05:00'
          }
        }
      end

      let(:appeals_failure_response_item_zero) do
        {
          'id' => '600118851',
          'type' => 'claim',
          'attributes' => {
            'subtype' => 'Compensation',
            'completed' => false,
            'dateFiled' => '2017-12-08'
          }
        }
      end

      it 'and claims service fails, but appeals succeeds' do
        VCR.use_cassette('evss/claims/claims_with_errors') do
          VCR.use_cassette('caseflow/appeals') do
            get '/mobile/v0/claims-and-appeals-overview', headers: iam_headers
            response_attributes = JSON.parse(response.body)['data']['attributes']
            expect(response).to have_http_status(:ok)
            expect(response_attributes['claimsAndAppeals']).not_to be_empty
            expect(response_attributes['claimsAndAppeals'][0]).to eq(claims_failure_response_item_zero)
            expect(response_attributes['claimsAndAppeals'].length).to eq(3)
            expect(response_attributes['upstreamServiceErrors'][0]['upstreamService']).to eq('claims')
          end
        end
      end

      it 'and appeals service fails, but claims succeeds' do
        VCR.use_cassette('evss/claims/claims') do
          VCR.use_cassette('caseflow/server_error') do
            get '/mobile/v0/claims-and-appeals-overview', headers: iam_headers
            response_attributes = JSON.parse(response.body)['data']['attributes']
            expect(response).to have_http_status(:ok)
            expect(response_attributes['claimsAndAppeals']).not_to be_empty
            expect(response_attributes['claimsAndAppeals'][0]).to eq(appeals_failure_response_item_zero)
            expect(response_attributes['claimsAndAppeals'].length).to eq(143)
            expect(response_attributes['upstreamServiceErrors'][0]['upstreamService']).to eq('appeals')
          end
        end
      end
      it 'both fail in upstream service' do
        VCR.use_cassette('evss/claims/claims_with_errors') do
          VCR.use_cassette('caseflow/server_error') do
            get '/mobile/v0/claims-and-appeals-overview', headers: iam_headers
            response_attributes = JSON.parse(response.body)['data']['attributes']
            expect(response).to have_http_status(:ok)
            expect(response_attributes['claimsAndAppeals']).to be_empty
            expect(response_attributes['upstreamServiceErrors'].length).to eq(2)
            expect(response_attributes['upstreamServiceErrors'][0]['upstreamService']).to eq('claims')
            expect(response_attributes['upstreamServiceErrors'][1]['upstreamService']).to eq('appeals')
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
