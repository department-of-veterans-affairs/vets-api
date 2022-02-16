# frozen_string_literal: true

require 'rails_helper'
require 'token_validation/v2/client'

RSpec.describe 'Claims', type: :request do
  let(:veteran_id) { '1013062086V794840' }
  let(:claim_id) { '600131328' }
  let(:all_claims_path) { "/services/benefits/v2/veterans/#{veteran_id}/claims" }
  let(:claim_by_id_path) { "/services/benefits/v2/veterans/#{veteran_id}/claims/#{claim_id}" }
  let(:scopes) { %w[claim.read] }

  describe 'Claims' do
    describe 'index' do
      context 'auth header' do
        context 'when provided' do
          it 'returns a 200' do
            with_okta_user(scopes) do |auth_header|
              expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                .to receive(:find_benefit_claims_status_by_ptcpnt_id).and_return(
                  benefit_claims_dto: {
                    benefit_claim: []
                  }
                )
              expect(ClaimsApi::AutoEstablishedClaim)
                .to receive(:where).and_return([])

              get all_claims_path, headers: auth_header
              expect(response.status).to eq(200)
            end
          end
        end

        context 'when not provided' do
          it 'returns a 401 error code' do
            with_okta_user(scopes) do
              get all_claims_path
              expect(response.status).to eq(401)
            end
          end
        end
      end

      context 'CCG (Client Credentials Grant) flow' do
        let(:ccg_token) { OpenStruct.new(client_credentials_token?: true, payload: { 'scp' => [] }) }

        context 'when provided' do
          context 'when valid' do
            it 'returns a 200' do
              allow(JWT).to receive(:decode).and_return(nil)
              allow(Token).to receive(:new).and_return(ccg_token)
              allow_any_instance_of(TokenValidation::V2::Client).to receive(:token_valid?).and_return(true)
              expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                .to receive(:find_benefit_claims_status_by_ptcpnt_id).and_return(
                  benefit_claims_dto: {
                    benefit_claim: []
                  }
                )
              expect(ClaimsApi::AutoEstablishedClaim)
                .to receive(:where).and_return([])

              get all_claims_path, headers: { 'Authorization' => 'Bearer HelloWorld' }
              expect(response.status).to eq(200)
            end
          end

          context 'when not valid' do
            it 'returns a 403' do
              allow(JWT).to receive(:decode).and_return(nil)
              allow(Token).to receive(:new).and_return(ccg_token)
              allow_any_instance_of(TokenValidation::V2::Client).to receive(:token_valid?).and_return(false)

              get all_claims_path, headers: { 'Authorization' => 'Bearer HelloWorld' }
              expect(response.status).to eq(403)
            end
          end
        end
      end

      context 'forbidden access' do
        context 'when current user is not the target veteran' do
          context 'when current user is not a representative of the target veteran' do
            it 'returns a 403' do
              with_okta_user(scopes) do |auth_header|
                expect_any_instance_of(ClaimsApi::V2::ApplicationController)
                  .to receive(:user_is_target_veteran?).and_return(false)
                expect_any_instance_of(ClaimsApi::V2::ApplicationController)
                  .to receive(:user_represents_veteran?).and_return(false)

                get all_claims_path, headers: auth_header
                expect(response.status).to eq(403)
              end
            end
          end
        end
      end

      context 'veteran_id param' do
        context 'when not provided' do
          let(:veteran_id) { nil }

          it 'returns a 404 error code' do
            with_okta_user(scopes) do |auth_header|
              get all_claims_path, headers: auth_header
              expect(response.status).to eq(404)
            end
          end
        end

        context 'when known veteran_id is provided' do
          it 'returns a 200' do
            with_okta_user(scopes) do |auth_header|
              expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                .to receive(:find_benefit_claims_status_by_ptcpnt_id).and_return(
                  benefit_claims_dto: {
                    benefit_claim: []
                  }
                )
              expect(ClaimsApi::AutoEstablishedClaim)
                .to receive(:where).and_return([])

              get all_claims_path, headers: auth_header
              expect(response.status).to eq(200)
            end
          end
        end

        context 'when unknown veteran_id is provided' do
          let(:veteran) { OpenStruct.new(mpi: nil, participant_id: nil) }

          it 'returns a 403 error code' do
            with_okta_user(scopes) do |auth_header|
              expect(ClaimsApi::Veteran).to receive(:new).and_return(veteran)

              get all_claims_path, headers: auth_header
              expect(response.status).to eq(403)
            end
          end
        end
      end

      describe 'mapping of claims' do
        context 'when BGS and Lighthouse claims exist' do
          context 'when a BGS claim is also in the Lighthouse collection' do
            let(:bgs_claims) do
              {
                benefit_claims_dto: {
                  benefit_claim: [
                    {
                      benefit_claim_id: '111111111',
                      claim_status_type: 'Compensation',
                      claim_dt: '2017-05-02',
                      phase_type: 'Pending',
                      attention_needed: 'Yes',
                      filed5103_waiver_ind: 'Y',
                      development_letter_sent: 'Yes',
                      decision_notification_sent: 'No'
                    }
                  ]
                }
              }
            end
            let(:lighthouse_claims) do
              [
                OpenStruct.new(
                  id: '0958d973-36fb-43ef-8801-2718bd33c825',
                  evss_id: '111111111',
                  claim_type: 'Compensation',
                  status: 'pending'
                )
              ]
            end

            it 'returns data for the claim with the given Lighthouse id, with other properties sourced from BGS' do
              with_okta_user(scopes) do |auth_header|
                expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                  .to receive(:find_benefit_claims_status_by_ptcpnt_id).and_return(bgs_claims)
                expect(ClaimsApi::AutoEstablishedClaim)
                  .to receive(:where).and_return(lighthouse_claims)

                get all_claims_path, headers: auth_header

                json_response = JSON.parse(response.body)
                expect(response.status).to eq(200)
                expect(json_response).to be_an_instance_of(Array)
                expect(json_response.count).to eq(1)
                claim = json_response.first
                expect(claim['id']).to eq('0958d973-36fb-43ef-8801-2718bd33c825')
                expect(claim['type']).to eq('Compensation')
                expect(claim['status']).to eq('Pending')
                expect(claim['date_filed']).to eq('05/02/17')
                expect(claim['documents_needed']).to eq(true)
                expect(claim['requested_decision']).to eq(true)
                expect(claim['development_letter_sent']).to eq(true)
                expect(claim['decision_letter_sent']).to eq(false)

                # End Product Code is omitted when getting all claims
                expect(claim['end_product_code']).to eq(nil)
              end
            end
          end

          context 'when a BGS claim is not in the Lighthouse collection' do
            let(:bgs_claims) do
              {
                benefit_claims_dto: {
                  benefit_claim: [
                    {
                      benefit_claim_id: '111111111',
                      claim_status_type: 'Compensation',
                      phase_type: 'Pending',
                      end_product_code: '930'
                    }
                  ]
                }
              }
            end
            let(:lighthouse_claims) do
              [
                OpenStruct.new(
                  id: '0958d973-36fb-43ef-8801-2718bd33c825',
                  evss_id: '222222222',
                  claim_type: 'Compensation',
                  status: 'pending'
                )
              ]
            end

            it 'returns a collection that contains both Lighthouse claim and BGS claim' do
              with_okta_user(scopes) do |auth_header|
                expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                  .to receive(:find_benefit_claims_status_by_ptcpnt_id).and_return(bgs_claims)
                expect(ClaimsApi::AutoEstablishedClaim)
                  .to receive(:where).and_return(lighthouse_claims)

                get all_claims_path, headers: auth_header

                json_response = JSON.parse(response.body)
                expect(response.status).to eq(200)
                expect(json_response).to be_an_instance_of(Array)
                expect(json_response.count).to eq(2)
                expect(json_response.any? { |claim| claim['id'] == '111111111' }).to be true
                expect(json_response.any? { |claim| claim['id'] == '0958d973-36fb-43ef-8801-2718bd33c825' }).to be true
              end
            end
          end
        end

        context 'when only BGS claims exist' do
          let(:bgs_claims) do
            {
              benefit_claims_dto: {
                benefit_claim: [
                  {
                    benefit_claim_id: '111111111',
                    claim_status_type: 'Compensation',
                    phase_type: 'Pending',
                    end_product_code: '930'
                  }
                ]
              }
            }
          end
          let(:lighthouse_claims) { [] }

          it 'returns a collection that contains the BGS claims' do
            with_okta_user(scopes) do |auth_header|
              expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                .to receive(:find_benefit_claims_status_by_ptcpnt_id).and_return(bgs_claims)
              expect(ClaimsApi::AutoEstablishedClaim)
                .to receive(:where).and_return(lighthouse_claims)

              get all_claims_path, headers: auth_header

              json_response = JSON.parse(response.body)
              expect(response.status).to eq(200)
              expect(json_response).to be_an_instance_of(Array)
              expect(json_response.count).to eq(1)
              expect(json_response.any? { |claim| claim['id'] == '111111111' }).to be true
            end
          end
        end

        context 'when only Lighthouse claims exist' do
          let(:bgs_claims) do
            {
              benefit_claims_dto: {
                benefit_claim: []
              }
            }
          end
          let(:lighthouse_claims) do
            [
              OpenStruct.new(
                id: '0958d973-36fb-43ef-8801-2718bd33c825',
                evss_id: '111111111',
                claim_type: 'Compensation',
                status: 'pending'
              )
            ]
          end

          it 'returns a collection that contains the Lighthouse claims' do
            with_okta_user(scopes) do |auth_header|
              expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                .to receive(:find_benefit_claims_status_by_ptcpnt_id).and_return(bgs_claims)
              expect(ClaimsApi::AutoEstablishedClaim)
                .to receive(:where).and_return(lighthouse_claims)

              get all_claims_path, headers: auth_header

              json_response = JSON.parse(response.body)

              expect(response.status).to eq(200)
              expect(json_response).to be_an_instance_of(Array)
              expect(json_response.count).to eq(1)
              expect(json_response.any? { |claim| claim['id'] == '0958d973-36fb-43ef-8801-2718bd33c825' }).to be true
            end
          end
        end

        context 'when no claims exist' do
          let(:bgs_claims) do
            {
              benefit_claims_dto: {
                benefit_claim: []
              }
            }
          end
          let(:lighthouse_claims) { [] }

          it 'returns an empty collection' do
            with_okta_user(scopes) do |auth_header|
              expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                .to receive(:find_benefit_claims_status_by_ptcpnt_id).and_return(bgs_claims)
              expect(ClaimsApi::AutoEstablishedClaim)
                .to receive(:where).and_return(lighthouse_claims)

              get all_claims_path, headers: auth_header

              json_response = JSON.parse(response.body)
              expect(response.status).to eq(200)
              expect(json_response).to be_an_instance_of(Array)
              expect(json_response.count).to eq(0)
            end
          end
        end
      end
    end

    describe 'show' do
      context 'when no auth header provided' do
        it 'returns a 401 error code' do
          with_okta_user(scopes) do
            get claim_by_id_path
            expect(response.status).to eq(401)
          end
        end
      end

      context 'when current user is not the target veteran' do
        context 'when current user is not a representative of the target veteran' do
          it 'returns a 403' do
            with_okta_user(scopes) do |auth_header|
              expect_any_instance_of(ClaimsApi::V2::ApplicationController)
                .to receive(:user_is_target_veteran?).and_return(false)
              expect_any_instance_of(ClaimsApi::V2::ApplicationController)
                .to receive(:user_represents_veteran?).and_return(false)

              get claim_by_id_path, headers: auth_header
              expect(response.status).to eq(403)
            end
          end
        end
      end

      context 'when looking for a Lighthouse claim' do
        let(:claim_id) { '123-abc-456-def' }

        context 'when a Lighthouse claim does not exist' do
          it 'returns a 404' do
            with_okta_user(scopes) do |auth_header|
              expect(ClaimsApi::AutoEstablishedClaim).to receive(:get_by_id_or_evss_id).and_return(nil)

              get claim_by_id_path, headers: auth_header

              expect(response.status).to eq(404)
            end
          end
        end

        context 'when a Lighthouse claim does exist' do
          let(:lighthouse_claim) do
            OpenStruct.new(
              id: '0958d973-36fb-43ef-8801-2718bd33c825',
              evss_id: '111111111',
              claim_type: 'Compensation',
              status: 'pending'
            )
          end

          context 'and a BGS claim does not exist' do
            let(:bgs_claim) { nil }

            it 'returns the Lighthouse claim' do
              with_okta_user(scopes) do |auth_header|
                expect(ClaimsApi::AutoEstablishedClaim)
                  .to receive(:get_by_id_or_evss_id).and_return(lighthouse_claim)
                expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                  .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim)

                get claim_by_id_path, headers: auth_header

                json_response = JSON.parse(response.body)
                expect(response.status).to eq(200)
                expect(response['endProductCode']).to eq(nil)
                expect(json_response).to be_an_instance_of(Hash)
                expect(json_response['id']).to eq('0958d973-36fb-43ef-8801-2718bd33c825')
              end
            end
          end

          context 'and a BGS claim does exist' do
            let(:bgs_claim) do
              {
                benefit_claim_details_dto: {
                  benefit_claim_id: '111111111',
                  claim_status_type: 'value from BGS',
                  bnft_claim_lc_status: {
                    phase_type: 'Pending'
                  }
                }
              }
            end

            it "returns a claim with the Lighthouse 'id', BGS 'type', & BGS 'status'" do
              with_okta_user(scopes) do |auth_header|
                expect(ClaimsApi::AutoEstablishedClaim)
                  .to receive(:get_by_id_or_evss_id).and_return(lighthouse_claim)
                expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                  .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim)

                get claim_by_id_path, headers: auth_header

                json_response = JSON.parse(response.body)
                expect(response.status).to eq(200)
                expect(json_response).to be_an_instance_of(Hash)
                expect(json_response['id']).to eq('0958d973-36fb-43ef-8801-2718bd33c825')
                expect(json_response['type']).to eq('value from BGS')
                expect(json_response['status']).to eq('Pending')
              end
            end
          end
        end
      end

      context 'when looking for a BGS claim' do
        let(:claim_id) { '123456789' }

        context 'when a BGS claim does not exist' do
          it 'returns a 404' do
            with_okta_user(scopes) do |auth_header|
              expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(nil)

              get claim_by_id_path, headers: auth_header

              expect(response.status).to eq(404)
            end
          end
        end

        context 'when a BGS claim does exist' do
          let(:bgs_claim) do
            {
              benefit_claim_details_dto: {
                benefit_claim_id: '111111111',
                claim_status_type: 'value from BGS',
                bnft_claim_lc_status: {
                  phase_type: 'Pending'
                }
              }
            }
          end

          context 'and a Lighthouse claim does exist' do
            let(:lighthouse_claim) do
              OpenStruct.new(
                id: '0958d973-36fb-43ef-8801-2718bd33c825',
                evss_id: '111111111',
                claim_type: 'Compensation',
                status: 'pending'
              )
            end

            it "returns a claim with the Lighthouse 'id' and the BGS 'type'" do
              with_okta_user(scopes) do |auth_header|
                expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                  .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim)
                expect(ClaimsApi::AutoEstablishedClaim)
                  .to receive(:get_by_id_or_evss_id).and_return(lighthouse_claim)

                get claim_by_id_path, headers: auth_header

                json_response = JSON.parse(response.body)
                expect(response.status).to eq(200)
                expect(json_response).to be_an_instance_of(Hash)
                expect(response['endProductCode']).to eq(nil)
                expect(json_response['id']).to eq('0958d973-36fb-43ef-8801-2718bd33c825')
                expect(json_response['type']).to eq('value from BGS')
              end
            end
          end

          context 'and a Lighthouse claim does not exit' do
            it "returns a claim with the BGS 'id'" do
              with_okta_user(scopes) do |auth_header|
                expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                  .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim)
                expect(ClaimsApi::AutoEstablishedClaim)
                  .to receive(:get_by_id_or_evss_id).and_return(nil)

                get claim_by_id_path, headers: auth_header

                json_response = JSON.parse(response.body)
                expect(response.status).to eq(200)
                expect(json_response).to be_an_instance_of(Hash)
                expect(json_response['id']).to eq('111111111')
              end
            end
          end
        end
      end

      context 'CCG (Client Credentials Grant)' do
        let(:claim_id) { '123-abc-456-def' }
        let(:lighthouse_claim) do
          OpenStruct.new(
            id: '0958d973-36fb-43ef-8801-2718bd33c825',
            evss_id: '111111111',
            claim_type: 'Compensation',
            status: 'pending'
          )
        end

        context 'when provided' do
          context 'when valid' do
            it 'returns a 200' do
              allow(JWT).to receive(:decode).and_return(nil)
              allow(Token).to receive(:new).and_return(
                OpenStruct.new(
                  client_credentials_token?: true,
                  payload: { 'scp' => [] }
                )
              )
              allow_any_instance_of(TokenValidation::V2::Client).to receive(:token_valid?).and_return(true)
              expect(ClaimsApi::AutoEstablishedClaim)
                .to receive(:get_by_id_or_evss_id).and_return(lighthouse_claim)
              expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(nil)

              get claim_by_id_path, headers: { 'Authorization' => 'Bearer HelloWorld' }
              expect(response.status).to eq(200)
            end
          end

          context 'when not valid' do
            it 'returns a 403' do
              allow(JWT).to receive(:decode).and_return(nil)
              allow(Token).to receive(:new).and_return(
                OpenStruct.new(
                  client_credentials_token?: true,
                  payload: { 'scp' => [] }
                )
              )
              allow_any_instance_of(TokenValidation::V2::Client).to receive(:token_valid?).and_return(false)

              get claim_by_id_path, headers: { 'Authorization' => 'Bearer HelloWorld' }
              expect(response.status).to eq(403)
            end
          end
        end
      end
    end
  end
end
