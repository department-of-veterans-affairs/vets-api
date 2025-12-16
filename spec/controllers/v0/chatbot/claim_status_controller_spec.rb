# frozen_string_literal: true

require 'rails_helper'
require 'chatbot/report_to_cxi'
require 'lighthouse/benefits_claims/constants'
require 'lighthouse/benefits_claims/service'
require 'lighthouse/benefits_claims/configuration'

RSpec.describe 'V0::Chatbot::ClaimStatusController', type: :request do
  include_context 'with service account authentication', 'foobar', ['http://www.example.com/v0/chatbot/claims'], { user_attributes: { icn: '123498767V234859' } }

  describe 'GET /v0/chatbot/claims from lighthouse' do
    subject(:get_claims) do
      get('/v0/chatbot/claims', params: { conversation_id: 123 }, headers: service_account_auth_header)
    end

    context 'authorized' do
      before do
        @mock_cxi_reporting_service = instance_double(Chatbot::ReportToCxi)
        allow(@mock_cxi_reporting_service).to receive(:report_to_cxi)

        allow_any_instance_of(BenefitsClaims::Configuration).to receive(:access_token).and_return('fake_access_token')

        allow(Chatbot::ReportToCxi)
          .to receive(:new)
          .and_return(@mock_cxi_reporting_service)
      end

      describe 'multiple claims from lighthouse' do
        it 'returns ordered list of all veteran claims from lighthouse' do
          VCR.use_cassette('lighthouse/benefits_claims/index/claims_chatbot_multiple_claims') do
            get_claims
            # get('/v0/chatbot/claims', params: { conversation_id: 123 }, headers: service_account_auth_header)
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
            get_claims
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
            get_claims
          end

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'SUCCESS'
          expect(JSON.parse(response.body)['data']).to be_a(Array)
          expect(JSON.parse(response.body)['data'].size).to eq(0)
        end
      end

      describe 'no claims found response from lighthouse' do
        it 'returns an empty array when lighthouse responds with resource not found' do
          benefits_claims_service = instance_double(BenefitsClaims::Service)
          allow(BenefitsClaims::Service).to receive(:new).and_return(benefits_claims_service)
          allow(benefits_claims_service).to receive(:get_claims)
            .and_raise(Common::Exceptions::ResourceNotFound.new(detail: 'Not found'))

          get_claims

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['data']).to eq([])
          expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'SUCCESS'
        end
      end

      describe 'no conversation id' do
        it 'raises exception when no conversation id is found' do
          VCR.use_cassette('lighthouse/benefits_claims/index/claims_chatbot_zero_claims') do
            get('/v0/chatbot/claims', headers: service_account_auth_header)
          end

          expect(response).to have_http_status(:bad_request)
        end
      end
    end
  end

  describe 'GET /v0/chatbot/claims/:id from lighthouse' do
    subject(:get_single_claim) do
      get('/v0/chatbot/claims/600383363', params: { conversation_id: 123 }, headers: service_account_auth_header)
    end

    context 'authorized' do
      before do
        allow(Flipper).to receive(:enabled?).and_call_original
        @mock_cxi_reporting_service = instance_double(Chatbot::ReportToCxi)
        allow(@mock_cxi_reporting_service).to receive(:report_to_cxi)

        allow_any_instance_of(BenefitsClaims::Configuration).to receive(:access_token).and_return('fake_access_token')

        allow(Chatbot::ReportToCxi)
          .to receive(:new)
          .and_return(@mock_cxi_reporting_service)
      end

      it 'overrides the tracked item status to NEEDED_FROM_OTHERS' do
        VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
          get_single_claim
        end
        parsed_body = JSON.parse(response.body)
        relevant_item = parsed_body.dig('data', 'data', 'attributes', 'trackedItems', 4)
        expect(relevant_item['displayName']).to eq('RV1 - Reserve Records Request')
        # In the cassette, this value is NEEDED_FROM_YOU
        expect(relevant_item['status']).to eq('NEEDED_FROM_OTHERS')
        expect(relevant_item['description']).to eq('RV1 can have its status overriden with a feature flipper.')
        expect(relevant_item['overdue']).to be(false)
        expect(relevant_item['friendlyName']).to eq('Reserve records')
        expect(relevant_item['activityDescription'])
          .to eq('We’ve requested your reserve records on your behalf. No action is needed.')
        expect(relevant_item['shortDescription'])
          .to eq('We’ve requested your service records or treatment records from your reserve unit.')
        expect(relevant_item['canUploadFile']).to be(true)
        expect(relevant_item['uploaded']).to be(true)
      end

      context 'when :cst_suppress_evidence_requests_website is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:cst_suppress_evidence_requests_website).and_return(true)
        end

        it 'excludes suppressed evidence request tracked items' do
          VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
            get_single_claim
          end
          parsed_body = JSON.parse(response.body)
          names = parsed_body.dig('data', 'data', 'attributes', 'trackedItems').map { |i| i['displayName'] }
          expect(names & BenefitsClaims::Constants::SUPPRESSED_EVIDENCE_REQUESTS).to be_empty
        end
      end

      context 'when :cst_suppress_evidence_requests_website is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:cst_suppress_evidence_requests_website).and_return(false)
        end

        it 'includes suppressed evidence request tracked items' do
          VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
            get_single_claim
          end
          parsed_body = JSON.parse(response.body)
          names = parsed_body.dig('data', 'data', 'attributes', 'trackedItems').map { |i| i['displayName'] }
          expect(names & BenefitsClaims::Constants::SUPPRESSED_EVIDENCE_REQUESTS).not_to be_empty
        end
      end
    end
  end
end
