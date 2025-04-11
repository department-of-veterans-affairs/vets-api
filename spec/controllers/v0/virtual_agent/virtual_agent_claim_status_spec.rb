# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_claims/service'
require 'lighthouse/benefits_claims/configuration'

RSpec.describe 'VirtualAgentClaimStatusController', type: :request do
  let(:user) { create(:user, :loa3, :accountable, icn: '123498767V234859') }

  describe 'GET /v0/virtual_agent/claims from lighthouse' do
    context 'authorized' do
      before do
        sign_in_as(user)

        @mock_cxdw_reporting_service = instance_double(V0::VirtualAgent::ReportToCxdw)
        allow(@mock_cxdw_reporting_service).to receive(:report_to_cxdw)

        allow_any_instance_of(BenefitsClaims::Configuration).to receive(:access_token).and_return('fake_access_token')

        allow(V0::VirtualAgent::ReportToCxdw)
          .to receive(:new)
          .and_return(@mock_cxdw_reporting_service)
      end

      describe 'multiple claims from lighthouse' do
        it 'returns ordered list of all veteran claims from lighthouse' do
          VCR.use_cassette('lighthouse/benefits_claims/index/claims_chatbot_multiple_claims') do
            get('/v0/virtual_agent/claims', params: { conversation_id: 123 })
          end

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['data'].size).to equal(3)
          expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'SUCCESS'
          expect(JSON.parse(response.body)['data']).to eq([{
                                                            'id' => '600173992',
                                                            'type' => 'claim',
                                                            'attributes' => {
                                                              'baseEndProductCode' => '403',
                                                              'claimDate' => '2023-12-02',
                                                              'claimPhaseDates' => {
                                                                'phaseChangeDate' => '2023-12-05'
                                                              },
                                                              'claimType' => 'Compensation',
                                                              'closeDate' => nil,
                                                              'decisionLetterSent' => false,
                                                              'developmentLetterSent' => false,
                                                              'documentsNeeded' => false,
                                                              'endProductCode' => '403',
                                                              'evidenceWaiverSubmitted5103' => false,
                                                              'lighthouseId' => nil,
                                                              'status' => 'INITIAL_REVIEW'
                                                            }
                                                          },
                                                           {
                                                             'id' => '600342023',
                                                             'type' => 'claim',
                                                             'attributes' => {
                                                               'baseEndProductCode' => '020',
                                                               'claimDate' => '2022-11-07',
                                                               'claimPhaseDates' => {
                                                                 'phaseChangeDate' => '2023-11-07'
                                                               },
                                                               'claimType' => 'Compensation',
                                                               'closeDate' => '2023-11-07',
                                                               'decisionLetterSent' => true,
                                                               'developmentLetterSent' => false,
                                                               'documentsNeeded' => false,
                                                               'endProductCode' => '020',
                                                               'evidenceWaiverSubmitted5103' => false,
                                                               'lighthouseId' => nil,
                                                               'status' => 'COMPLETE'
                                                             }
                                                           },
                                                           {
                                                             'id' => '600173694',
                                                             'type' => 'claim',
                                                             'attributes' => {
                                                               'baseEndProductCode' => '110',
                                                               'claimDate' => '2023-05-23',
                                                               'claimPhaseDates' => {
                                                                 'phaseChangeDate' => '2023-06-17'
                                                               },
                                                               'claimType' => 'Compensation',
                                                               'closeDate' => nil,
                                                               'decisionLetterSent' => false,
                                                               'developmentLetterSent' => false,
                                                               'documentsNeeded' => false,
                                                               'endProductCode' => '110',
                                                               'evidenceWaiverSubmitted5103' => false,
                                                               'lighthouseId' => nil,
                                                               'status' => 'PREPARATION_FOR_NOTIFICATION'
                                                             }
                                                           }])
        end
      end

      describe 'single claim' do
        it 'returns single open compensation claim' do
          VCR.use_cassette('lighthouse/benefits_claims/index/claims_chatbot_single_claim') do
            get('/v0/virtual_agent/claims', params: { conversation_id: 123 })
          end

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'SUCCESS'
          expect(JSON.parse(response.body)['data']).to be_a(Array)
          expect(JSON.parse(response.body)['data'].size).to equal(1)
          expect(JSON.parse(response.body)['data']).to eq([{
                                                            'id' => '600173694',
                                                            'type' => 'claim',
                                                            'attributes' => {
                                                              'baseEndProductCode' => '110',
                                                              'claimDate' => '2023-05-23',
                                                              'claimPhaseDates' => {
                                                                'phaseChangeDate' => '2023-06-17'
                                                              },
                                                              'claimType' => 'Compensation',
                                                              'closeDate' => nil,
                                                              'decisionLetterSent' => false,
                                                              'developmentLetterSent' => false,
                                                              'documentsNeeded' => false,
                                                              'endProductCode' => '110',
                                                              'evidenceWaiverSubmitted5103' => false,
                                                              'lighthouseId' => nil,
                                                              'status' => 'PREPARATION_FOR_NOTIFICATION'
                                                            }
                                                          }])
        end
      end

      describe 'no claims' do
        it 'returns empty array when no open claims are found' do
          VCR.use_cassette('lighthouse/benefits_claims/index/claims_chatbot_zero_claims') do
            get('/v0/virtual_agent/claims', params: { conversation_id: 123 })
          end

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'SUCCESS'
          expect(JSON.parse(response.body)['data']).to be_a(Array)
          expect(JSON.parse(response.body)['data'].size).to eq(0)
        end
      end

      describe 'no conversation id' do
        it 'raises exception when no conversation id is found' do
          VCR.use_cassette('lighthouse/benefits_claims/index/claims_chatbot_zero_claims') do
            get '/v0/virtual_agent/claims'
          end

          expect(response).to have_http_status(:bad_request)
        end
      end
    end
  end

  describe 'GET /v0/virtual_agent/claims/:id from lighthouse' do
    context 'authorized' do
      before do
        sign_in_as(user)

        @mock_cxdw_reporting_service = instance_double(V0::VirtualAgent::ReportToCxdw)
        allow(@mock_cxdw_reporting_service).to receive(:report_to_cxdw)

        allow_any_instance_of(BenefitsClaims::Configuration).to receive(:access_token).and_return('fake_access_token')

        allow(V0::VirtualAgent::ReportToCxdw)
          .to receive(:new)
          .and_return(@mock_cxdw_reporting_service)
      end

      context 'when cst_override_reserve_records_website flipper is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).and_call_original
          allow(Flipper).to receive(:enabled?).with(:cst_override_reserve_records_website).and_return(true)
        end

        it 'overrides the tracked item status to NEEDED_FROM_OTHERS' do
          VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
            get('/v0/virtual_agent/claims/600383363')
          end
          parsed_body = JSON.parse(response.body)
          expect(parsed_body.dig('data', 'data', 'attributes', 'trackedItems', 2,
                                 'displayName')).to eq('RV1 - Reserve Records Request')
          # In the cassette, this value is NEEDED_FROM_YOU
          expect(parsed_body.dig('data', 'data', 'attributes', 'trackedItems', 2, 'status')).to eq('NEEDED_FROM_OTHERS')
        end
      end

      context 'when cst_override_reserve_records_website flipper is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).and_call_original
          allow(Flipper).to receive(:enabled?).with(:cst_override_reserve_records_website).and_return(false)
        end

        it 'leaves the tracked item status as NEEDED_FROM_YOU' do
          VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
            get('/v0/virtual_agent/claims/600383363')
          end
          parsed_body = JSON.parse(response.body)
          expect(parsed_body.dig('data', 'data', 'attributes', 'trackedItems', 2,
                                 'displayName')).to eq('RV1 - Reserve Records Request')
          # Do not override the cassette value
          expect(parsed_body.dig('data', 'data', 'attributes', 'trackedItems', 2, 'status')).to eq('NEEDED_FROM_YOU')
        end
      end

      context 'when :cst_suppress_evidence_requests_website is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).and_call_original
          allow(Flipper).to receive(:enabled?).with(:cst_suppress_evidence_requests_website).and_return(true)
        end

        it 'excludes Attorney Fees, Secondary Action Required, and Stage 2 Development tracked items' do
          VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
            get('/v0/virtual_agent/claims/600383363')
          end
          parsed_body = JSON.parse(response.body)
          expect(parsed_body.dig('data', 'data', 'attributes', 'trackedItems').size).to eq(13)
          expect(parsed_body.dig('data', 'data', 'attributes', 'trackedItems', 0,
                                 'displayName')).to eq('Private Medical Record')
          expect(parsed_body.dig('data', 'data', 'attributes', 'trackedItems', 1,
                                 'displayName')).to eq('Submit buddy statement(s)')
        end
      end

      context 'when :cst_suppress_evidence_requests_website is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).and_call_original
          allow(Flipper).to receive(:enabled?).with(:cst_suppress_evidence_requests_website).and_return(false)
        end

        it 'includes Attorney Fees, Secondary Action Required, and Stage 2 Development tracked items' do
          VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
            get('/v0/virtual_agent/claims/600383363')
          end
          parsed_body = JSON.parse(response.body)
          expect(parsed_body.dig('data', 'data', 'attributes', 'trackedItems').size).to eq(14)
          expect(parsed_body.dig('data', 'data', 'attributes', 'trackedItems', 0,
                                 'displayName')).to eq('Private Medical Record')
          expect(parsed_body.dig('data', 'data', 'attributes', 'trackedItems', 1,
                                 'displayName')).to eq('Submit buddy statement(s)')
          expect(parsed_body.dig('data', 'data', 'attributes', 'trackedItems', 2, 'displayName')).to eq('Attorney Fees')
        end
      end
    end
  end
end
