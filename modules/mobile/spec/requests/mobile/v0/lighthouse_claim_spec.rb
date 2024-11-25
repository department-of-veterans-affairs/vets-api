# frozen_string_literal: true

require_relative '../../../support/helpers/rails_helper'
require_relative '../../../support/helpers/committee_helper'

require 'lighthouse/benefits_claims/configuration'
require 'lighthouse/benefits_claims/service'

RSpec.describe 'Mobile::V0::Claim', type: :request do
  include JsonSchemaMatchers
  include CommitteeHelper

  let!(:user) { sis_user(icn: '1008596379V859838') }

  describe 'GET /v0/claim/:id with lighthouse upstream service' do
    before do
      token = 'abcdefghijklmnop'
      allow_any_instance_of(BenefitsClaims::Configuration).to receive(:access_token).and_return(token)
      Flipper.enable_actor(:mobile_lighthouse_claims, user)
    end

    after { Flipper.disable(:mobile_lighthouse_claims) }

    context 'when the claim is found' do
      it 'matches our schema is successfully returned with the 200 status',
         run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
        VCR.use_cassette('mobile/lighthouse_claims/show/200_response') do
          get '/mobile/v0/claim/600117255', headers: sis_headers
        end

        tracked_item_with_no_docs = response.parsed_body.dig('data', 'attributes', 'eventsTimeline').select do |event|
          event['trackedItemId'] == 360_055
        end.first
        tracked_item_with_docs = response.parsed_body.dig('data', 'attributes', 'eventsTimeline').select do |event|
          event['trackedItemId'] == 360_052
        end.first

        assert_schema_conform(200)

        expect(tracked_item_with_docs['documents'].count).to eq(1)
        expect(tracked_item_with_docs['uploaded']).to eq(true)
        expect(tracked_item_with_no_docs['documents'].count).to eq(0)
        expect(tracked_item_with_no_docs['uploaded']).to eq(false)

        uploaded_of_events = response.parsed_body.dig('data', 'attributes', 'eventsTimeline').pluck('uploaded').compact
        date_of_events = response.parsed_body.dig('data', 'attributes', 'eventsTimeline').pluck('date')

        expect(uploaded_of_events).to eq([false, false, false, true, true, true, true, true])
        expect(date_of_events).to eq(['2022-10-30', '2022-10-30', '2022-09-30', '2023-03-01', '2022-12-12',
                                      '2022-10-30', '2022-10-30', '2022-10-11', '2022-09-30', '2022-09-30',
                                      '2022-09-27', nil, nil, nil, nil, nil, nil, nil, nil])
        expect(response.parsed_body.dig('data', 'attributes', 'claimTypeCode')).to eq('020NEW')
      end
    end

    context 'with a non-existent claim' do
      it 'returns a 404 with an error',
         run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
        VCR.use_cassette('mobile/lighthouse_claims/show/404_response') do
          get '/mobile/v0/claim/60038334', headers: sis_headers

          assert_schema_conform(404)
          expect(response.parsed_body).to eq({ 'errors' => [{ 'title' => 'Resource not found',
                                                              'detail' => 'Resource not found',
                                                              'code' => '404', 'status' => '404' }] })
        end
      end
    end
  end
end
