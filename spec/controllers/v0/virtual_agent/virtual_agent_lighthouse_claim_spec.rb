# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_claims/service'
require 'lighthouse/benefits_claims/configuration'

RSpec.describe 'VirtualAgentClaimsController', type: :request do
  let(:user) { create(:user, :loa3, :accountable, icn: '123498767V234859') }

  describe 'GET /v0/virtual_agent/claim from lighthouse' do
    context 'authorized' do
      before do
        Flipper.enable(:virtual_agent_lighthouse_claims)

        sign_in_as(user)

        @mock_cxdw_reporting_service = instance_double(V0::VirtualAgent::ReportToCxdw)
        allow(@mock_cxdw_reporting_service).to receive(:report_to_cxdw)

        allow_any_instance_of(BenefitsClaims::Configuration).to receive(:access_token).and_return('fake_access_token')

        allow(V0::VirtualAgent::ReportToCxdw)
          .to receive(:new)
          .and_return(@mock_cxdw_reporting_service)
      end

      describe 'multiple claims form lighthouse' do
        it 'returns ok status from lighthouse -- happy path' do
          VCR.use_cassette('lighthouse/benefits_claims/index/claims_multiple_open_compensation_claims') do
            get '/v0/virtual_agent/claim'
          end

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['data'].size).to equal(3)
          expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'SUCCESS'
          expect(JSON.parse(response.body)['data']).to eq([{
                                                            'claim_type' => 'Compensation',
                                                            'claim_status' => 'INITIAL_REVIEW',
                                                            'filing_date' => '12/02/2019',
                                                            'id' => '600173992',
                                                            'updated_date' => '12/05/2019'
                                                          },
                                                           {
                                                             'claim_type' => 'Compensation',
                                                             'claim_status' => 'INITIAL_REVIEW',
                                                             'filing_date' => '11/20/2019',
                                                             'id' => '600173694',
                                                             'updated_date' => '11/27/2019'
                                                           },
                                                           {
                                                             'claim_type' => 'Compensation',
                                                             'claim_status' => 'INITIAL_REVIEW',
                                                             'filing_date' => '09/10/2019',
                                                             'id' => '600166396',
                                                             'updated_date' => '09/10/2019'
                                                           }])
        end
      end

      describe 'single claims' do
        it 'returns information on single open compensation claim' do
          VCR.use_cassette('lighthouse/benefits_claims/index/claims_with_single_open_compensation_claim') do
            get '/v0/virtual_agent/claim'
          end

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'SUCCESS'
          expect(JSON.parse(response.body)['data']).to be_a(Array)
          expect(JSON.parse(response.body)['data'].size).to equal(1)
          expect(JSON.parse(response.body)['data']).to include({
                                                                 'claim_type' => 'Compensation',
                                                                 'claim_status' => 'INITIAL_REVIEW',
                                                                 'filing_date' => '12/02/2019',
                                                                 'id' => '600173992',
                                                                 'updated_date' => '12/05/2019'
                                                               })
        end
      end

      describe 'no claims' do
        it 'returns empty array when no open claims are found' do
          VCR.use_cassette('lighthouse/benefits_claims/index/no_open_compensation_claims') do
            get '/v0/virtual_agent/claim'
          end

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'SUCCESS'
          expect(JSON.parse(response.body)['data']).to be_a(Array)
          expect(JSON.parse(response.body)['data'].size).to equal(0)
        end

        it 'returns empty array when there are only closed compensation claims' do
          VCR.use_cassette('lighthouse/benefits_claims/index/only_closed_comp_claims') do
            get '/v0/virtual_agent/claim'
          end

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'SUCCESS'
          expect(JSON.parse(response.body)['data']).to be_a(Array)
          expect(JSON.parse(response.body)['data'].size).to equal(0)
        end
      end
    end
  end
end
