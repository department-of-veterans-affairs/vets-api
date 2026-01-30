# frozen_string_literal: true

require_relative '../../../support/helpers/rails_helper'
require_relative '../../../support/helpers/committee_helper'

require 'lighthouse/benefits_claims/configuration'
require 'lighthouse/benefits_claims/constants'
require 'lighthouse/benefits_claims/service'

RSpec.describe 'Mobile::V0::Claim', type: :request do
  include JsonSchemaMatchers
  include CommitteeHelper

  let!(:user) { sis_user(icn: '1008596379V859838') }
  let(:user_account) { create(:user_account) }

  describe 'GET /v0/claim/:id with lighthouse upstream service' do
    before do
      allow(Flipper).to receive(:enabled?).with(:cst_multi_claim_provider_mobile, anything).and_return(false)
      token = 'abcdefghijklmnop'
      allow_any_instance_of(BenefitsClaims::Configuration).to receive(:access_token).and_return(token)
    end

    context 'when the claim is found' do
      before do
        allow(Flipper).to receive(:enabled?).and_call_original
        allow(Flipper).to receive(:enabled?).with(:cst_multi_claim_provider_mobile, anything).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:cst_suppress_evidence_requests_mobile).and_return(false)
      end

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
        expect(tracked_item_with_docs['uploaded']).to be(true)
        expect(tracked_item_with_no_docs['documents'].count).to eq(0)
        expect(tracked_item_with_no_docs['uploaded']).to be(false)

        uploaded_of_events = response.parsed_body.dig('data', 'attributes', 'eventsTimeline').pluck('uploaded').compact
        date_of_events = response.parsed_body.dig('data', 'attributes', 'eventsTimeline').pluck('date')

        expect(uploaded_of_events).to eq([false, false, false, false, true, true, true, true, true])
        expect(date_of_events).to eq(['2022-10-30', '2022-10-30', '2022-10-30', '2022-09-30', '2023-03-01',
                                      '2022-12-12', '2022-10-30', '2022-10-30', '2022-10-11', '2022-09-30',
                                      '2022-09-30', '2022-09-27', nil, nil, nil, nil, nil, nil, nil, nil])
        expect(response.parsed_body.dig('data', 'attributes', 'claimTypeCode')).to eq('020NEW')

        expect(response.parsed_body.dig('data', 'attributes')).to have_key('downloadEligibleDocuments')
        download_eligible_documents = response.parsed_body.dig('data', 'attributes', 'downloadEligibleDocuments')

        expect(download_eligible_documents).to be_a(Array)
        expect(download_eligible_documents.size).to eq(5)
        expect(download_eligible_documents[0]['documentId']).to eq('{883B6CC8-D726-4911-9C65-2EB360E12F52}')
        expect(download_eligible_documents[0]['filename'].strip).to eq('7B434B58-477C-4379-816F-05E6D3A10487.pdf')
      end

      context 'when cst_override_reserve_records_mobile flipper is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).and_call_original
          allow(Flipper).to receive(:enabled?).with(:cst_multi_claim_provider_mobile, anything).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:cst_override_reserve_records_mobile).and_return(true)
        end

        it 'overrides the tracked item status to NEEDED_FROM_OTHERS', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
          VCR.use_cassette('mobile/lighthouse_claims/show/200_response') do
            get '/mobile/v0/claim/600117255', headers: sis_headers
          end
          tracked_item = response.parsed_body.dig('data', 'attributes', 'eventsTimeline').select do |event|
            event['trackedItemId'] == 360_057
          end.first
          expect(tracked_item['displayName']).to eq('RV1 - Reserve Records Request')
          expect(tracked_item['type']).to eq('still_need_from_others_list')
        end
      end

      context 'when cst_override_reserve_records_mobile flipper is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).and_call_original
          allow(Flipper).to receive(:enabled?).with(:cst_multi_claim_provider_mobile, anything).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:cst_override_reserve_records_mobile).and_return(false)
        end

        it 'leaves the tracked item status as NEEDED_FROM_YOU', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
          VCR.use_cassette('mobile/lighthouse_claims/show/200_response') do
            get '/mobile/v0/claim/600117255', headers: sis_headers
          end
          tracked_item = response.parsed_body.dig('data', 'attributes', 'eventsTimeline').select do |event|
            event['trackedItemId'] == 360_057
          end.first
          expect(tracked_item['displayName']).to eq('RV1 - Reserve Records Request')
          expect(tracked_item['type']).to eq('still_need_from_you_list')
        end
      end

      context 'when :cst_suppress_evidence_requests_mobile is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).and_call_original
          allow(Flipper).to receive(:enabled?).with(:cst_multi_claim_provider_mobile, anything).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:cst_suppress_evidence_requests_mobile).and_return(true)
        end

        it 'excludes suppressed evidence request tracked items' do
          VCR.use_cassette('mobile/lighthouse_claims/show/200_response') do
            get '/mobile/v0/claim/600117255', headers: sis_headers
          end
          parsed_body = JSON.parse(response.body)
          display_names = parsed_body.dig('data', 'attributes', 'eventsTimeline').map { |h| h['displayName'] }
          expect(display_names.size).to eq(19)
          expect(display_names & BenefitsClaims::Constants::SUPPRESSED_EVIDENCE_REQUESTS).to be_empty
        end
      end

      context 'when :cst_suppress_evidence_requests_mobile is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).and_call_original
          allow(Flipper).to receive(:enabled?).with(:cst_multi_claim_provider_mobile, anything).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:cst_suppress_evidence_requests_mobile).and_return(false)
        end

        it 'includes suppressed evidence request tracked items' do
          VCR.use_cassette('mobile/lighthouse_claims/show/200_response') do
            get '/mobile/v0/claim/600117255', headers: sis_headers
          end
          parsed_body = JSON.parse(response.body)
          display_names = parsed_body.dig('data', 'attributes', 'eventsTimeline').map { |h| h['displayName'] }
          expect(display_names.size).to eq(20)
          expect(display_names & BenefitsClaims::Constants::SUPPRESSED_EVIDENCE_REQUESTS).not_to be_empty
        end
      end

      context 'when :schema_contract_claims_and_appeals_get_claim is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).and_call_original
          allow(Flipper).to receive(:enabled?).with(:cst_multi_claim_provider_mobile, anything).and_return(false)
          allow(Flipper).to receive(:enabled?).with('schema_contract_claims_and_appeals_get_claim').and_return(true)

          user.user_account_uuid = user_account.id
          user.save!
        end

        it 'validates schema' do
          VCR.use_cassette('mobile/lighthouse_claims/show/200_response') do
            get '/mobile/v0/claim/600117255', headers: sis_headers
          end
          SchemaContract::ValidationJob.drain
          expect(SchemaContract::Validation.last.status).to eq('success')
        end
      end
    end

    context 'with a non-existent claim' do
      before do
        allow(Flipper).to receive(:enabled?).and_call_original
        allow(Flipper).to receive(:enabled?).with(:cst_multi_claim_provider_mobile, anything).and_return(false)
      end

      it 'returns a 404 with an error',
         run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
        VCR.use_cassette('mobile/lighthouse_claims/show/404_response') do
          get '/mobile/v0/claim/60038334', headers: sis_headers

          assert_schema_conform(404)
          expect(response.parsed_body).to eq({ 'errors' => [{ 'title' => 'Resource not found',
                                                              'detail' => 'Claim not found',
                                                              'code' => '404', 'status' => '404' }] })
        end
      end
    end
  end
end
