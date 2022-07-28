# frozen_string_literal: true

require 'rails_helper'
require 'token_validation/v2/client'

RSpec.describe 'Claims', type: :request do
  let(:veteran_id) { '1013062086V794840' }
  let(:claim_id) { '600131328' }
  let(:all_claims_path) { "/services/claims/v2/veterans/#{veteran_id}/claims" }
  let(:claim_by_id_path) { "/services/claims/v2/veterans/#{veteran_id}/claims/#{claim_id}" }
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
        describe "handling 'lighthouseId' and 'claimId'" do
          context 'when BGS and Lighthouse claims exist' do
            let(:bgs_claims) do
              {
                benefit_claims_dto: {
                  benefit_claim: [
                    {
                      benefit_claim_id: '111111111'
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
                  status: 'pending'
                )
              ]
            end

            it "provides values for 'lighthouseId' and 'claimId' " do
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
                expect(claim['claimId']).to eq('111111111')
                expect(claim['lighthouseId']).to eq('0958d973-36fb-43ef-8801-2718bd33c825')
              end
            end
          end

          context 'when only a BGS claim exists' do
            let(:bgs_claims) do
              {
                benefit_claims_dto: {
                  benefit_claim: [
                    {
                      benefit_claim_id: '111111111'
                    }
                  ]
                }
              }
            end
            let(:lighthouse_claims) { [] }

            it "provides a value for 'claimId', but 'lighthouseId' will be 'nil' " do
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
                expect(claim['claimId']).to eq('111111111')
                expect(claim['lighthouseId']).to be nil
              end
            end
          end

          context 'when only a Lighthouse claim exists' do
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
                  status: 'pending'
                )
              ]
            end

            it "provides a value for 'lighthouseId', but 'claimId' will be 'nil' " do
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
                expect(claim['lighthouseId']).to eq('0958d973-36fb-43ef-8801-2718bd33c825')
                expect(claim['claimId']).to be nil
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
              status: 'pending'
            )
          end

          context 'and a BGS claim does not exist' do
            let(:bgs_claim) { nil }

            describe "handling 'lighthouseId' and 'claimId'" do
              it "provides a value for 'lighthouseId', but 'claimId' will be 'nil' " do
                with_okta_user(scopes) do |auth_header|
                  expect(ClaimsApi::AutoEstablishedClaim)
                    .to receive(:get_by_id_or_evss_id).and_return(lighthouse_claim)
                  expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                    .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim)

                  get claim_by_id_path, headers: auth_header

                  json_response = JSON.parse(response.body)
                  expect(response.status).to eq(200)
                  expect(json_response).to be_an_instance_of(Hash)
                  expect(json_response['lighthouseId']).to eq('0958d973-36fb-43ef-8801-2718bd33c825')
                  expect(json_response['claimId']).to be nil
                end
              end
            end
          end

          context 'and a BGS claim does exist' do
            let(:bgs_claim) do
              {
                benefit_claim_details_dto: {
                  benefit_claim_id: '111111111'
                }
              }
            end

            describe "handling 'lighthouseId' and 'claimId'" do
              it "provides a value for 'lighthouseId' and 'claimId'" do
                with_okta_user(scopes) do |auth_header|
                  expect(ClaimsApi::AutoEstablishedClaim)
                    .to receive(:get_by_id_or_evss_id).and_return(lighthouse_claim)
                  expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                    .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim)

                  get claim_by_id_path, headers: auth_header

                  json_response = JSON.parse(response.body)
                  expect(response.status).to eq(200)
                  expect(json_response).to be_an_instance_of(Hash)
                  expect(json_response['lighthouseId']).to eq('0958d973-36fb-43ef-8801-2718bd33c825')
                  expect(json_response['claimId']).to eq('111111111')
                end
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
                benefit_claim_id: '111111111'
              }
            }
          end

          context 'and a Lighthouse claim exists' do
            let(:lighthouse_claim) do
              OpenStruct.new(
                id: '0958d973-36fb-43ef-8801-2718bd33c825',
                evss_id: '111111111',
                status: 'pending'
              )
            end

            describe "handling 'lighthouseId' and 'claimId'" do
              it "provides a value for 'lighthouseId' and 'claimId'" do
                with_okta_user(scopes) do |auth_header|
                  expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                    .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim)
                  expect(ClaimsApi::AutoEstablishedClaim)
                    .to receive(:get_by_id_or_evss_id).and_return(lighthouse_claim)

                  get claim_by_id_path, headers: auth_header

                  json_response = JSON.parse(response.body)
                  expect(response.status).to eq(200)
                  expect(json_response).to be_an_instance_of(Hash)
                  expect(json_response['lighthouseId']).to eq('0958d973-36fb-43ef-8801-2718bd33c825')
                  expect(json_response['claimId']).to eq('111111111')
                end
              end
            end
          end

          context 'and a Lighthouse claim does not exit' do
            it "provides a value for 'claimId', but 'lighthouseId' will be 'nil' " do
              with_okta_user(scopes) do |auth_header|
                expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                  .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim)
                expect(ClaimsApi::AutoEstablishedClaim)
                  .to receive(:get_by_id_or_evss_id).and_return(nil)

                get claim_by_id_path, headers: auth_header

                json_response = JSON.parse(response.body)
                expect(response.status).to eq(200)
                expect(json_response).to be_an_instance_of(Hash)
                expect(json_response['claimId']).to eq('111111111')
                expect(json_response['lighthouseId']).to be nil
              end
            end
          end
        end
      end

      describe "handling the 'status'" do
        context 'when there is 1 status' do
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

          it "sets the 'status'" do
            with_okta_user(scopes) do |auth_header|
              expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim)
              expect(ClaimsApi::AutoEstablishedClaim)
                .to receive(:get_by_id_or_evss_id).and_return(nil)

              get claim_by_id_path, headers: auth_header

              json_response = JSON.parse(response.body)
              expect(response.status).to eq(200)
              expect(json_response).to be_an_instance_of(Hash)
              expect(json_response['status']).to eq('Pending')
            end
          end
        end

        context 'it picks the newest status' do
          let(:bgs_claim) do
            {
              benefit_claim_details_dto: {
                benefit_claim_id: '111111111',
                claim_status_type: 'value from BGS',
                bnft_claim_lc_status: [{
                  phas_chngd_dt: DateTime.now,
                  phase_type: 'Pending'
                }, {
                  phas_chngd_dt: DateTime.now - 1.day,
                  phase_type: 'In Review'
                }]
              }
            }
          end

          it "returns a claim with the 'claimId' and 'lighthouseId' set" do
            with_okta_user(scopes) do |auth_header|
              expect_any_instance_of(BGS::EbenefitsBenefitClaimsStatus)
                .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim)
              expect(ClaimsApi::AutoEstablishedClaim)
                .to receive(:get_by_id_or_evss_id).and_return(nil)

              get claim_by_id_path, headers: auth_header

              json_response = JSON.parse(response.body)
              expect(response.status).to eq(200)
              expect(json_response).to be_an_instance_of(Hash)
              expect(json_response['claimType']).to eq('value from BGS')
              expect(json_response['status']).to eq('Pending')
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
