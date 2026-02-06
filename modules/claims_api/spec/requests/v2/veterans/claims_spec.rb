# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../rails_helper'
require 'token_validation/v2/client'
require 'bgs_service/local_bgs'
require 'bgs_service/person_web_service'
require 'bgs_service/e_benefits_bnft_claim_status_web_service'
require 'bgs_service/tracked_item_service'
require 'concerns/claims_api/v2/claims_requests/supporting_documents'

RSpec.describe 'ClaimsApi::V2::Veterans::Claims', type: :request do
  let(:veteran_id) { '1013062086V794840' }
  let(:file_number) { '796111863' }
  let(:claimant_on_behalf_of_veteran_id) { '8675309' }
  let(:claim_id) { '600131328' }
  let(:all_claims_path) { "/services/claims/v2/veterans/#{veteran_id}/claims" }
  let(:claim_by_id_path) { "/services/claims/v2/veterans/#{veteran_id}/claims/#{claim_id}" }
  let(:claim_by_id_with_claimant_path) do
    "/services/claims/v2/veterans/#{claimant_on_behalf_of_veteran_id}/claims/#{claim_id}"
  end
  let(:scopes) { %w[system/claim.read] }
  let(:profile) do
    MPI::Responses::FindProfileResponse.new(
      status: :ok,
      profile: build(:mpi_profile,
                     participant_id: nil,
                     participant_ids: [])
    )
  end
  let(:bnft_claim_web_service) { ClaimsApi::EbenefitsBnftClaimStatusWebService }
  let(:profile_for_claimant_on_behalf_of_veteran) do
    MPI::Responses::FindProfileResponse.new(
      status: :ok,
      profile: build(:mpi_profile,
                     participant_id: '8675309')
    )
  end
  let(:profile_erroneous_icn) do
    MPI::Responses::FindProfileResponse.new(
      status: :not_found,
      profile: build(:mpi_profile, icn: '667711332299')
    )
  end
  let(:person_web_service) do
    ClaimsApi::PersonWebService.new(
      external_uid: target_veteran.participant_id,
      external_key: target_veteran.participant_id
    )
  end
  let(:target_veteran) do
    OpenStruct.new(
      icn: '1013062086V794840',
      first_name: 'abraham',
      last_name: 'lincoln',
      loa: { current: 3, highest: 3 },
      ssn: '796111863',
      edipi: '8040545646',
      participant_id: '600061742',
      mpi: OpenStruct.new(
        icn: '1013062086V794840',
        profile: OpenStruct.new(ssn: '796111863')
      )
    )
  end

  describe 'Claims' do
    before do
      allow(Flipper).to receive(:enabled?).with(:claims_load_testing).and_return false
      allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_use_birls_id).and_return false
      allow(Flipper).to receive(:enabled?).with(:claims_api_use_person_web_service).and_return true
      allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_add_person_proxy).and_return true
    end

    describe 'index' do
      context 'auth header' do
        context 'when provided' do
          it 'returns a 200' do
            mock_ccg(scopes) do |auth_header|
              expect_any_instance_of(bnft_claim_web_service)
                .to receive(:find_benefit_claims_status_by_ptcpnt_id).and_return(
                  benefit_claims_dto: {
                    benefit_claim: []
                  }
                )
              expect(ClaimsApi::AutoEstablishedClaim)
                .to receive(:where).and_return([])

              get all_claims_path, headers: auth_header
              expect(response).to have_http_status(:ok)
            end
          end
        end

        context 'when not provided' do
          it 'returns a 401 error code' do
            get all_claims_path
            expect(response).to have_http_status(:unauthorized)
          end
        end
      end

      context 'CCG (Client Credentials Grant) flow' do
        let(:ccg_token) { OpenStruct.new(client_credentials_token?: true, payload: { 'scp' => [] }) }

        context 'when provided' do
          context 'when valid' do
            it 'returns a 200' do
              mock_ccg(scopes) do |auth_header|
                expect_any_instance_of(bnft_claim_web_service)
                  .to receive(:find_benefit_claims_status_by_ptcpnt_id).and_return(
                    benefit_claims_dto: {
                      benefit_claim: []
                    }
                  )
                expect(ClaimsApi::AutoEstablishedClaim)
                  .to receive(:where).and_return([])

                get all_claims_path, headers: auth_header
                expect(response).to have_http_status(:ok)
              end
            end
          end

          context 'when not valid' do
            it 'returns a 401' do
              mock_ccg(scopes) do |auth_header|
                allow_any_instance_of(ClaimsApi::ValidatedToken).to receive(:validated_token_data).and_return(nil)
                get all_claims_path, headers: auth_header
                expect(response).to have_http_status(:unauthorized)
              end
            end
          end
        end
      end

      context 'veteran_id param' do
        context 'when not provided' do
          let(:veteran_id) { nil }

          it 'returns a 404 error code' do
            mock_ccg(scopes) do |auth_header|
              get all_claims_path, headers: auth_header
              expect(response).to have_http_status(:not_found)
            end
          end
        end

        context 'when known veteran_id is provided' do
          it 'returns a 200' do
            mock_ccg(scopes) do |auth_header|
              expect_any_instance_of(bnft_claim_web_service)
                .to receive(:find_benefit_claims_status_by_ptcpnt_id).and_return(
                  benefit_claims_dto: {
                    benefit_claim: []
                  }
                )
              expect(ClaimsApi::AutoEstablishedClaim)
                .to receive(:where).and_return([])

              get all_claims_path, headers: auth_header
              expect(response).to have_http_status(:ok)
            end
          end
        end

        context 'when unknown veteran_id is provided' do
          it 'returns a 404 error code' do
            mock_ccg(scopes) do |auth_header|
              allow_any_instance_of(ClaimsApi::Veteran).to receive(:mpi_record?).and_return(nil)

              get all_claims_path, headers: auth_header
              expect(response).to have_http_status(:not_found)
            end
          end
        end
      end

      describe 'BGS attributes' do
        let(:bgs_claims) do
          {
            benefit_claims_dto: {
              benefit_claim: [
                {
                  benefit_claim_id: '600098193',
                  claim_status: 'Pending',
                  claim_status_type: 'Compensation',
                  phase_chngd_dt: 'Wed, 18 Oct 2017',
                  phase_type: 'Complete',
                  ptcpnt_clmant_id: veteran_id,
                  ptcpnt_vet_id: veteran_id,
                  phase_type_change_ind: '76'
                }
              ]
            }
          }
        end

        it 'are listed' do
          lighthouse_claim = create(:auto_established_claim, status: 'established', veteran_icn: veteran_id,
                                                             evss_id: '600098193')
          lighthouse_claim_two = create(:auto_established_claim, status: 'pending', veteran_icn: veteran_id,
                                                                 evss_id: nil)

          lh_claims = ClaimsApi::AutoEstablishedClaim.where(id: [lighthouse_claim.id, lighthouse_claim_two.id])

          mock_ccg(scopes) do |auth_header|
            VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
              expect_any_instance_of(bnft_claim_web_service)
                .to receive(:find_benefit_claims_status_by_ptcpnt_id).and_return(bgs_claims)
              expect(ClaimsApi::AutoEstablishedClaim)
                .to receive(:where).and_return(lh_claims)

              get all_claims_path, headers: auth_header

              json_response = JSON.parse(response.body)
              expect(response).to have_http_status(:ok)
              claim = json_response['data'].first
              claim_two = json_response['data'][1]
              expect(claim['attributes']['status']).to eq('COMPLETE')
              expect(claim_two['attributes']['status']).to eq('PENDING')
              expect(claim['attributes']['claimPhaseDates']['phaseChangeDate']).to eq('2017-10-18')
            end
          end
        end
      end

      describe 'mapping of claims' do
        describe 'handling duplicate claims in BGS and LH' do
          let(:bgs_claims) do
            {
              benefit_claims_dto: {
                benefit_claim: [
                  {
                    benefit_claim_id: '600098191',
                    claim_status: 'Pending',
                    claim_status_type: 'Compensation',
                    phase_chngd_dt: 'Wed, 18 Oct 2017',
                    phase_type: 'Complete',
                    ptcpnt_clmant_id: veteran_id,
                    ptcpnt_vet_id: veteran_id,
                    phase_type_change_ind: '76'
                  },
                  {
                    benefit_claim_id: '600098192',
                    claim_status: 'Pending',
                    claim_status_type: 'Compensation',
                    phase_chngd_dt: 'Wed, 18 Oct 2017',
                    phase_type: 'Complete',
                    ptcpnt_clmant_id: veteran_id,
                    ptcpnt_vet_id: veteran_id,
                    phase_type_change_ind: '76'
                  },
                  {
                    benefit_claim_id: '600098193',
                    claim_status: 'Pending',
                    claim_status_type: 'Compensation',
                    phase_chngd_dt: 'Wed, 18 Oct 2017',
                    phase_type: 'Complete',
                    ptcpnt_clmant_id: veteran_id,
                    ptcpnt_vet_id: veteran_id,
                    phase_type_change_ind: '76'
                  }
                ]
              }
            }
          end

          context 'when there are multiple matching claims' do
            it 'does not list duplicates for any matching claims between BGS and LH' do
              lighthouse_claim = create(:auto_established_claim, status: 'PEND', veteran_icn: veteran_id,
                                                                 evss_id: '600098191')
              lighthouse_claim_two = create(:auto_established_claim, status: 'PEND', veteran_icn: veteran_id,
                                                                     evss_id: '600098193')

              lh_claims = ClaimsApi::AutoEstablishedClaim.where(id: [lighthouse_claim.id, lighthouse_claim_two.id])

              mock_ccg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
                  expect_any_instance_of(bnft_claim_web_service)
                    .to receive(:find_benefit_claims_status_by_ptcpnt_id).and_return(bgs_claims)
                  expect(ClaimsApi::AutoEstablishedClaim)
                    .to receive(:where).and_return(lh_claims)

                  get all_claims_path, headers: auth_header

                  json_response = JSON.parse(response.body)

                  expect(response).to have_http_status(:ok)
                  expect(json_response['data'].count).to eq(3)
                  expect(json_response['data'][0]['id'])
                    .to eq(bgs_claims[:benefit_claims_dto][:benefit_claim][0][:benefit_claim_id])
                  expect(json_response['data'][0]['id']).to eq(lighthouse_claim.evss_id.to_s)
                  expect(json_response['data'][2]['id'])
                    .to eq(bgs_claims[:benefit_claims_dto][:benefit_claim][2][:benefit_claim_id])
                  expect(json_response['data'][2]['id']).to eq(lighthouse_claim_two.evss_id.to_s)
                end
              end
            end
          end

          context 'when there are unique LH and BGS claims' do
            it 'lists unique claims and does not list duplicates for any matching claims between BGS and LH' do
              lighthouse_claim = create(:auto_established_claim, status: 'PEND', veteran_icn: veteran_id,
                                                                 evss_id: '600098191')
              lighthouse_claim_two = create(:auto_established_claim, status: 'PEND', veteran_icn: veteran_id,
                                                                     evss_id: '600098193')
              lighthouse_claim_three = create(:auto_established_claim, status: 'PEND', veteran_icn: veteran_id,
                                                                       evss_id: '600098195')
              lh_claims = ClaimsApi::AutoEstablishedClaim.where(
                id: [lighthouse_claim.id, lighthouse_claim_two.id, lighthouse_claim_three.id]
              )

              mock_ccg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
                  expect_any_instance_of(bnft_claim_web_service)
                    .to receive(:find_benefit_claims_status_by_ptcpnt_id).and_return(bgs_claims)
                  expect(ClaimsApi::AutoEstablishedClaim)
                    .to receive(:where).and_return(lh_claims)

                  get all_claims_path, headers: auth_header

                  json_response = JSON.parse(response.body)
                  expect(response).to have_http_status(:ok)
                  expect(json_response['data'].count).to eq(4)
                  expect(json_response['data'][0]['attributes']['lighthouseId']).to eq(lighthouse_claim.id)
                  expect(json_response['data'][1]['attributes']['lighthouseId']).to be_nil
                  expect(json_response['data'][2]['attributes']['lighthouseId']).to eq(lighthouse_claim_two.id)
                  expect(json_response['data'][3]['attributes']['lighthouseId']).to eq(lighthouse_claim_three.id)
                  expect(json_response['data'][3]['attributes']['claimType']).to eq('Compensation')
                  expect(json_response['data'][3]['id']).to be_nil
                end
              end
            end
          end
        end

        describe "handling 'lighthouseId' and 'claimId'" do
          context 'when BGS and Lighthouse claims exist' do
            let(:bgs_claims) do
              {
                benefit_claims_dto: {
                  benefit_claim: [
                    {
                      base_end_prdct_type_cd: '400',
                      benefit_claim_id: '111111111',
                      claim_status: 'PEND',
                      phase_type: 'Gathering of Evidence'
                    }
                  ]
                }
              }
            end

            it "provides values for 'lighthouseId' and 'claimId'" do
              lighthouse_claim = create(
                :auto_established_claim,
                id: '0958d973-36fb-43ef-8801-2718bd33c825',
                status: 'pending',
                evss_id: '111111111'
              )

              lighthouse_claims = ClaimsApi::AutoEstablishedClaim.where(
                id: [lighthouse_claim.id]
              )

              mock_ccg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
                  expect_any_instance_of(bnft_claim_web_service)
                    .to receive(:find_benefit_claims_status_by_ptcpnt_id).and_return(bgs_claims)
                  expect(ClaimsApi::AutoEstablishedClaim)
                    .to receive(:where).and_return(lighthouse_claims)

                  get all_claims_path, headers: auth_header

                  json_response = JSON.parse(response.body)

                  expect(response).to have_http_status(:ok)
                  expect(json_response['data']).to be_an_instance_of(Array)
                  expect(json_response.count).to eq(1)
                  claim = json_response['data'].first
                  expect(claim['attributes']['baseEndProductCode']).to eq('400')
                  expect(claim['attributes']['status']).to eq('EVIDENCE_GATHERING_REVIEW_DECISION')
                  expect(claim['id']).to eq('111111111')
                  expect(claim['attributes']['lighthouseId']).to eq('0958d973-36fb-43ef-8801-2718bd33c825')
                end
              end
            end
          end

          context 'when only a BGS claim exists' do
            let(:bgs_claims) do
              {
                benefit_claims_dto: {
                  benefit_claim: [
                    {
                      base_end_prdct_type_cd: '400',
                      benefit_claim_id: '111111111',
                      phase_type: 'claim received'
                    }
                  ]
                }
              }
            end
            let(:lighthouse_claims) { [] }

            it "provides a value for 'claimId', but 'lighthouseId' will be 'nil'" do
              mock_ccg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
                  expect_any_instance_of(bnft_claim_web_service)
                    .to receive(:find_benefit_claims_status_by_ptcpnt_id).and_return(bgs_claims)
                  expect(ClaimsApi::AutoEstablishedClaim)
                    .to receive(:where).and_return(lighthouse_claims)

                  get all_claims_path, headers: auth_header

                  json_response = JSON.parse(response.body)
                  expect(response).to have_http_status(:ok)
                  expect(json_response['data']).to be_an_instance_of(Array)
                  expect(json_response.count).to eq(1)
                  claim = json_response['data'].first
                  expect(claim['attributes']['baseEndProductCode']).to eq('400')
                  expect(claim['attributes']['status']).to eq('CLAIM_RECEIVED')
                  expect(claim['id']).to eq('111111111')
                  expect(claim['attributes']['lighthouseId']).to be_nil
                end
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
                  status: 'pend'
                )
              ]
            end

            it "provides a value for 'lighthouseId', but 'claimId' will be 'nil'" do
              mock_ccg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
                  expect_any_instance_of(bnft_claim_web_service)
                    .to receive(:find_benefit_claims_status_by_ptcpnt_id).and_return(bgs_claims)
                  expect(ClaimsApi::AutoEstablishedClaim)
                    .to receive(:where).and_return(lighthouse_claims)

                  get all_claims_path, headers: auth_header

                  json_response = JSON.parse(response.body)

                  expect(response).to have_http_status(:ok)
                  expect(json_response['data']).to be_an_instance_of(Array)
                  expect(json_response.count).to eq(1)
                  claim = json_response['data'].first
                  expect(claim['attributes']['status']).to eq('PENDING')
                  expect(claim['attributes']['lighthouseId']).to eq('0958d973-36fb-43ef-8801-2718bd33c825')
                  expect(claim['id']).to be_nil
                end
              end
            end

            it "provides a value for 'lighthouseId', but 'claimId' will be 'nil' when bgs returns nil" do
              mock_ccg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
                  expect_any_instance_of(bnft_claim_web_service)
                    .to receive(:find_benefit_claims_status_by_ptcpnt_id).and_return(nil)
                  expect(ClaimsApi::AutoEstablishedClaim)
                    .to receive(:where).and_return(lighthouse_claims)

                  get all_claims_path, headers: auth_header

                  json_response = JSON.parse(response.body)

                  expect(response).to have_http_status(:ok)
                  expect(json_response['data']).to be_an_instance_of(Array)
                  expect(json_response.count).to eq(1)
                  claim = json_response['data'].first
                  expect(claim['attributes']['status']).to eq('PENDING')
                  expect(claim['attributes']['lighthouseId']).to eq('0958d973-36fb-43ef-8801-2718bd33c825')
                  expect(claim['id']).to be_nil
                end
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
              mock_ccg(scopes) do |auth_header|
                expect_any_instance_of(bnft_claim_web_service)
                  .to receive(:find_benefit_claims_status_by_ptcpnt_id).and_return(bgs_claims)
                expect(ClaimsApi::AutoEstablishedClaim)
                  .to receive(:where).and_return(lighthouse_claims)

                get all_claims_path, headers: auth_header

                json_response = JSON.parse(response.body)
                expect(response).to have_http_status(:ok)
                expect(json_response['data']).to be_an_instance_of(Array)
                expect(json_response['data'].count).to eq(0)
              end
            end
          end
        end
      end

      describe 'participant ID' do
        context 'when missing' do
          let(:add_person_proxy_response) do
            instance_double(MPI::Responses::AddPersonResponse, ok?: false)
          end

          let(:bgs_claims) do
            {
              benefit_claims_dto: {
                benefit_claim: [
                  {
                    base_end_prdct_type_cd: '400',
                    benefit_claim_id: '111111111',
                    phase_type: 'claim received'
                  }
                ]
              }
            }
          end

          it 'returns a 422' do
            mock_ccg(scopes) do |auth_header|
              allow_any_instance_of(bnft_claim_web_service)
                .to receive(:find_benefit_claims_status_by_ptcpnt_id).and_return(bgs_claims)
              allow_any_instance_of(ClaimsApi::Veteran).to receive(:mpi_record?).and_return(true)
              allow_any_instance_of(MPIData)
                .to receive(:mvi_response).and_return(profile)
              allow_any_instance_of(MPIData)
                .to receive(:add_person_proxy).and_return(add_person_proxy_response)
              allow(add_person_proxy_response)
                .to receive(:error)

              get all_claims_path, headers: auth_header

              json_response = JSON.parse(response.body)
              expect(response).to have_http_status(:unprocessable_entity)
              expect(json_response['errors'][0]['detail']).to eq(
                "Unable to locate Veteran's Participant ID in Master Person Index (MPI). " \
                'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.'
              )
            end
          end
        end
      end
    end

    describe 'show with validate_id_with_icn' do
      let(:bgs_claim_response) { build(:bgs_response_with_one_lc_status).to_h }

      describe 'BGS attributes' do
        it 'are listed' do
          lh_claim = create(:auto_established_claim, status: 'PENDING', veteran_icn: veteran_id,
                                                     evss_id: '111111111')
          mock_ccg(scopes) do |auth_header|
            VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
              VCR.use_cassette('claims_api/evss/documents/get_claim_documents') do
                bgs_claim_response[:benefit_claim_details_dto][:ptcpnt_vet_id] = '600061742'
                expect_any_instance_of(bnft_claim_web_service)
                  .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim_response)
                expect(ClaimsApi::AutoEstablishedClaim)
                  .to receive(:get_by_id_and_icn).and_return(lh_claim)
                get claim_by_id_path, headers: auth_header
                json_response = JSON.parse(response.body)
                expect(response).to have_http_status(:ok)
                expect(json_response['data']['attributes']['claimPhaseDates']['currentPhaseBack']).to be(false)
                expect(json_response['data']['attributes']['claimPhaseDates']['latestPhaseType'])
                  .to eq('CLAIM_RECEIVED')
                expect(json_response['data']['attributes']['claimPhaseDates']['previousPhases']).to be_truthy
              end
            end
          end
        end
      end
    end

    context 'show with validate_id_with_icn when there is a claimant ID in place of the veteran ID' do
      describe 'BGS attributes (w/ Claimant ID replacing vet ID)' do
        it 'are listed' do
          bgs_claim_response = build(:bgs_response_claim_with_unmatched_ptcpnt_vet_id).to_h
          lh_claim = create(:auto_established_claim, status: 'PENDING', veteran_icn: '2023062086V8675309',
                                                     evss_id: '111111111')
          mock_ccg(scopes) do |auth_header|
            VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
              VCR.use_cassette('claims_api/evss/documents/get_claim_documents') do
                expect_any_instance_of(bnft_claim_web_service)
                  .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim_response)

                expect(ClaimsApi::AutoEstablishedClaim)
                  .to receive(:get_by_id_and_icn).and_return(lh_claim)

                allow_any_instance_of(MPIData)
                  .to receive(:mvi_response).and_return(profile_for_claimant_on_behalf_of_veteran)

                get claim_by_id_path, headers: auth_header
                json_response = JSON.parse(response.body)
                expect(response).to have_http_status(:ok)
                expect(json_response).to be_an_instance_of(Hash)
              end
            end
          end
        end
      end
    end

    describe 'show' do
      let(:bgs_claim_response) { build(:bgs_response_with_one_lc_status).to_h }

      before do
        allow_any_instance_of(ClaimsApi::V2::Veterans::ClaimsController)
          .to receive(:validate_id_with_icn).and_return(nil)
      end

      describe 'BGS attributes' do
        it 'are listed' do
          lh_claim = create(:auto_established_claim, status: 'PENDING', veteran_icn: veteran_id,
                                                     evss_id: '111111111')
          mock_ccg(scopes) do |auth_header|
            VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
              VCR.use_cassette('claims_api/evss/documents/get_claim_documents') do
                expect_any_instance_of(bnft_claim_web_service)
                  .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim_response)
                expect(ClaimsApi::AutoEstablishedClaim)
                  .to receive(:get_by_id_and_icn).and_return(lh_claim)

                get claim_by_id_path, headers: auth_header

                json_response = JSON.parse(response.body)
                expect(response).to have_http_status(:ok)
                claim_attributes = json_response['data']['attributes']
                expect(claim_attributes['claimPhaseDates']['currentPhaseBack']).to be(false)
                expect(claim_attributes['claimPhaseDates']['latestPhaseType']).to eq('CLAIM_RECEIVED')
                expect(claim_attributes['claimPhaseDates']['previousPhases']).to be_truthy
              end
            end
          end
        end
      end

      it 'uses BD when it should', vcr: 'claims_api/v2/claims_show' do
        allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_use_birls_id).and_return false
        lh_claim = create(:auto_established_claim, status: 'PENDING', veteran_icn: veteran_id,
                                                   evss_id: '111111111')
        mock_ccg(scopes) do |auth_header|
          expect_any_instance_of(bnft_claim_web_service)
            .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim_response)
          expect(ClaimsApi::AutoEstablishedClaim)
            .to receive(:get_by_id_and_icn).and_return(lh_claim)
          expect_any_instance_of(ClaimsApi::V2::BenefitsDocuments::Service)
            .to receive(:get_auth_token).and_return('some-value-here')

          get claim_by_id_path, headers: auth_header
          json_response = JSON.parse(response.body)

          expect(response).to have_http_status(:ok)
          expect(json_response['data']['attributes']['supportingDocuments'].length).to eq(2)
        end
      end

      context 'when no auth header provided' do
        it 'returns a 401 error code' do
          get claim_by_id_path
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'when looking for a Lighthouse claim' do
        let(:claim_id) { '123-abc-456-def' }

        context 'when a Lighthouse claim does not exist' do
          it 'returns a 404' do
            mock_ccg(scopes) do |auth_header|
              expect(ClaimsApi::AutoEstablishedClaim).to receive(:get_by_id_and_icn).and_return(nil)

              get claim_by_id_path, headers: auth_header

              expect(response).to have_http_status(:not_found)
            end
          end
        end

        context 'when a Lighthouse claim does exist' do
          let(:lighthouse_claim) do
            create(:auto_established_claim, status: 'PENDING', veteran_icn: '1013062086V794840',
                                            evss_id: '111111111')
          end
          let(:matched_claim_veteran_path) do
            "/services/claims/v2/veterans/#{lighthouse_claim.veteran_icn}/claims/#{lighthouse_claim.id}"
          end

          context 'and is not associated with the current user' do
            let(:not_vet_lh_claim) do
              create(:auto_established_claim, status: 'PENDING', veteran_icn: '456')
            end
            let(:mismatched_claim_veteran_path) do
              "/services/claims/v2/veterans/#{lighthouse_claim.veteran_icn}/claims/#{not_vet_lh_claim.id}"
            end

            it 'returns a 404' do
              mock_ccg(scopes) do |auth_header|
                get mismatched_claim_veteran_path, headers: auth_header

                expect(response).to have_http_status(:not_found)
              end
            end
          end

          context 'and is associated with the current user' do
            let(:bgs_claim) { nil }

            it 'returns a 200' do
              mock_ccg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
                  expect_any_instance_of(bnft_claim_web_service)
                    .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim)

                  get matched_claim_veteran_path, headers: auth_header

                  expect(response).to have_http_status(:ok)
                end
              end
            end
          end

          context 'and a BGS claim does not exist' do
            let(:bgs_claim) { nil }

            describe "handling 'lighthouseId' and 'claimId'" do
              it "provides a value for 'lighthouseId', but 'claimId' will be 'nil'" do
                mock_ccg(scopes) do |auth_header|
                  VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
                    expect_any_instance_of(bnft_claim_web_service)
                      .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim)

                    get matched_claim_veteran_path, headers: auth_header

                    json_response = JSON.parse(response.body)
                    expect(response).to have_http_status(:ok)
                    expect(json_response).to be_an_instance_of(Hash)
                    expect(json_response['data']['attributes']['status']).to eq('PENDING')
                    expect(json_response['data']['id']).to be_nil
                  end
                end
              end
            end
          end

          context 'and a BGS claim does exist' do
            let(:bgs_claim) { build(:bgs_response_with_one_lc_status) }

            describe "handling 'lighthouseId' and 'claimId'" do
              it "provides a value for 'lighthouseId' and 'claimId'" do
                mock_ccg(scopes) do |auth_header|
                  VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
                    VCR.use_cassette('claims_api/evss/documents/get_claim_documents') do
                      expect(ClaimsApi::AutoEstablishedClaim)
                        .to receive(:get_by_id_and_icn).and_return(lighthouse_claim)
                      expect_any_instance_of(bnft_claim_web_service)
                        .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim)

                      get matched_claim_veteran_path, headers: auth_header

                      json_response = JSON.parse(response.body)
                      expect(response).to have_http_status(:ok)
                      expect(json_response).to be_an_instance_of(Hash)
                      expect(json_response['data']['attributes']['lighthouseId']).to eq(lighthouse_claim.id)
                      expect(json_response['data']['id']).to eq('111111111')
                    end
                  end
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
            mock_ccg(scopes) do |auth_header|
              expect_any_instance_of(bnft_claim_web_service)
                .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(nil)

              get claim_by_id_path, headers: auth_header

              expect(response).to have_http_status(:not_found)
            end
          end
        end

        context 'when a BGS claim does exist' do
          let(:bgs_claim) { build(:bgs_response_with_one_lc_status).to_h }

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
                mock_ccg(scopes) do |auth_header|
                  VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
                    VCR.use_cassette('claims_api/evss/documents/get_claim_documents') do
                      expect_any_instance_of(bnft_claim_web_service)
                        .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim)
                      expect(ClaimsApi::AutoEstablishedClaim)
                        .to receive(:get_by_id_and_icn).and_return(lighthouse_claim)

                      get claim_by_id_path, headers: auth_header

                      json_response = JSON.parse(response.body)
                      expect(response).to have_http_status(:ok)
                      claim_attributes = json_response['data']['attributes']
                      expect(json_response).to be_an_instance_of(Hash)
                      expect(claim_attributes['lighthouseId']).to eq('0958d973-36fb-43ef-8801-2718bd33c825')
                      expect(json_response['data']['id']).to eq('111111111')
                    end
                  end
                end
              end
            end
          end

          context 'and a Lighthouse claim does not exit' do
            it "provides a value for 'claimId', but 'lighthouseId' will be 'nil'" do
              mock_ccg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
                  VCR.use_cassette('claims_api/evss/documents/get_claim_documents') do
                    expect_any_instance_of(bnft_claim_web_service)
                      .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim)
                    expect(ClaimsApi::AutoEstablishedClaim)
                      .to receive(:get_by_id_and_icn).and_return(nil)

                    get claim_by_id_path, headers: auth_header

                    json_response = JSON.parse(response.body)
                    expect(response).to have_http_status(:ok)
                    expect(json_response).to be_an_instance_of(Hash)
                    expect(json_response['data']['id']).to eq('111111111')
                    expect(json_response['data']['attributes']['lighthouseId']).to be_nil
                  end
                end
              end
            end
          end

          describe 'when there is no file number returned from BGS' do
            context 'when the file_number is nil' do
              it 'returns an empty array and not a 404' do
                mock_ccg(scopes) do |auth_header|
                  VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
                    VCR.use_cassette('claims_api/evss/documents/get_claim_documents') do
                      allow_any_instance_of(ClaimsApi::V2::Veterans::ClaimsController)
                        .to receive(:use_birls_id_file_number?).and_return(false)

                      expect_any_instance_of(bnft_claim_web_service)
                        .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim)
                      allow(person_web_service).to receive(:find_by_ssn).with('123456789').and_return(nil)
                      get claim_by_id_path, headers: auth_header

                      json_response = JSON.parse(response.body)

                      expect(json_response['data']['attributes']['supportingDocuments']).to eq([])
                      expect(response).not_to have_http_status(:not_found)
                    end
                  end
                end
              end
            end
          end

          describe 'when BD is enabled, and using birls_id as the file number' do
            context 'when the file_number is nil' do
              let(:no_ssn_target_veteran) do
                OpenStruct.new(
                  icn: '1012832025V743496',
                  first_name: 'Wesley',
                  last_name: 'Ford',
                  birth_date: '19630211',
                  loa: { current: 3, highest: 3 },
                  edipi: '2536798',
                  ssn: nil,
                  participant_id: '600061742',
                  birls_id: nil,
                  mpi: OpenStruct.new(
                    icn: '1012832025V743496',
                    profile: OpenStruct.new(ssn: '796043735', birls_id: nil)
                  )
                )
              end

              it 'returns an empty array and not a 404' do
                mock_ccg(scopes) do |auth_header|
                  VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
                    VCR.use_cassette('claims_api/evss/documents/get_claim_documents') do
                      allow_any_instance_of(ClaimsApi::V2::Veterans::ClaimsController)
                        .to receive(:use_birls_id_file_number?).and_return(true)
                      allow_any_instance_of(ClaimsApi::V2::Veterans::ClaimsController)
                        .to receive(:target_veteran).and_return(no_ssn_target_veteran)

                      expect_any_instance_of(bnft_claim_web_service)
                        .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim)
                      allow(person_web_service).to receive(:find_by_ssn).with('1233456789').and_return(nil)

                      get claim_by_id_path, headers: auth_header

                      json_response = JSON.parse(response.body)
                      expect(json_response['data']['attributes']['supportingDocuments']).to eq([])
                      expect(response).not_to have_http_status(:not_found)
                    end
                  end
                end
              end
            end

            context 'when the birls_id is present' do
              let(:no_ssn_target_veteran) do
                OpenStruct.new(
                  icn: '1012832025V743496',
                  first_name: 'Wesley',
                  last_name: 'Ford',
                  birth_date: '19630211',
                  loa: { current: 3, highest: 3 },
                  edipi: '2536798',
                  ssn: nil,
                  participant_id: '600061742',
                  birls_id: '796043735',
                  mpi: OpenStruct.new(
                    icn: '1012832025V743496',
                    profile: OpenStruct.new(ssn: nil, birls_id: '796043735')
                  )
                )
              end

              it 'the file_number should equal the birls_id' do
                mock_ccg(scopes) do |auth_header|
                  VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
                    VCR.use_cassette('claims_api/evss/documents/get_claim_documents') do
                      allow_any_instance_of(ClaimsApi::V2::Veterans::ClaimsController)
                        .to receive(:use_birls_id_file_number?).and_return(true)
                      allow_any_instance_of(ClaimsApi::V2::Veterans::ClaimsController)
                        .to receive(:target_veteran).and_return(no_ssn_target_veteran)

                      expect_any_instance_of(bnft_claim_web_service)
                        .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim)
                      allow(person_web_service).to receive(:find_by_ssn).with('796043735').and_return('796043735')

                      benefits_doc_api = double
                      allow_any_instance_of(ClaimsApi::V2::Veterans::ClaimsController)
                        .to receive(:benefits_doc_api)
                        .and_return(benefits_doc_api)

                      expect(benefits_doc_api).to receive(:search).with(claim_id, '796043735')

                      get claim_by_id_path, headers: auth_header

                      expect(response).to have_http_status(:ok)
                    end
                  end
                end
              end
            end
          end
        end
      end

      describe "handling the 'status'" do
        context 'when there is 1 status' do
          it "sets the 'status'" do
            mock_ccg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
                VCR.use_cassette('claims_api/evss/documents/get_claim_documents') do
                  expect_any_instance_of(bnft_claim_web_service)
                    .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim_response)
                  expect(ClaimsApi::AutoEstablishedClaim)
                    .to receive(:get_by_id_and_icn).and_return(nil)

                  get claim_by_id_path, headers: auth_header

                  json_response = JSON.parse(response.body)
                  expect(response).to have_http_status(:ok)
                  expect(json_response).to be_an_instance_of(Hash)
                  expect(json_response['data']['attributes']['status']).to eq('EVIDENCE_GATHERING_REVIEW_DECISION')
                end
              end
            end
          end
        end

        context 'when the claim is complete' do
          let(:bgs_claim) { build(:bgs_response_with_lc_status).to_h }

          it 'shows a closed date' do
            mock_ccg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
                VCR.use_cassette('claims_api/evss/documents/get_claim_documents') do
                  expect_any_instance_of(bnft_claim_web_service)
                    .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim)
                  expect(ClaimsApi::AutoEstablishedClaim)
                    .to receive(:get_by_id_and_icn).and_return(nil)

                  get claim_by_id_path, headers: auth_header

                  d = Date.parse(bgs_claim[:benefit_claim_details_dto][:claim_complete_dt].to_s)
                  expected_date = d.strftime('%Y-%m-%d')
                  json_response = JSON.parse(response.body)
                  expect(response).to have_http_status(:ok)
                  expect(json_response).to be_an_instance_of(Hash)
                  expect(json_response['data']['attributes']['closeDate']).to eq(expected_date)
                end
              end
            end
          end
        end

        context 'when a typical status is received' do
          it "the v2 mapper sets the correct 'status'" do
            mock_ccg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
                VCR.use_cassette('claims_api/evss/documents/get_claim_documents') do
                  expect_any_instance_of(bnft_claim_web_service)
                    .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim_response)
                  expect(ClaimsApi::AutoEstablishedClaim)
                    .to receive(:get_by_id_and_icn).and_return(nil)

                  get claim_by_id_path, headers: auth_header

                  json_response = JSON.parse(response.body)
                  expect(response).to have_http_status(:ok)
                  expect(json_response).to be_an_instance_of(Hash)
                  expect(json_response['data']['attributes']['status']).to eq('EVIDENCE_GATHERING_REVIEW_DECISION')
                end
              end
            end
          end
        end

        context 'when a grouped status is received' do
          let(:bgs_claim) do
            {
              benefit_claim_details_dto: {
                benefit_claim_id: '111111111',
                claim_status_type: 'value from BGS',
                bnft_claim_lc_status: {
                  phase_type: 'Pending Decision Approval'
                }
              }
            }
          end

          it "the v2 mapper sets the 'status' correctly" do
            mock_ccg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
                VCR.use_cassette('claims_api/evss/documents/get_claim_documents') do
                  expect_any_instance_of(bnft_claim_web_service)
                    .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim_response)
                  expect(ClaimsApi::AutoEstablishedClaim)
                    .to receive(:get_by_id_and_icn).and_return(nil)

                  get claim_by_id_path, headers: auth_header

                  json_response = JSON.parse(response.body)
                  expect(response).to have_http_status(:ok)
                  expect(json_response).to be_an_instance_of(Hash)
                  expect(json_response['data']['attributes']['status']).to eq('EVIDENCE_GATHERING_REVIEW_DECISION')
                end
              end
            end
          end
        end

        context 'when an Under Review status is received' do
          let(:bgs_claim) { build(:bgs_response_with_under_review_lc_status).to_h }

          it "the v2 mapper sets the 'status' correctly" do
            mock_ccg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
                VCR.use_cassette('claims_api/evss/documents/get_claim_documents') do
                  expect_any_instance_of(bnft_claim_web_service)
                    .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim)
                  expect(ClaimsApi::AutoEstablishedClaim)
                    .to receive(:get_by_id_and_icn).and_return(nil)

                  get claim_by_id_path, headers: auth_header

                  json_response = JSON.parse(response.body)
                  expect(response).to have_http_status(:ok)
                  expect(json_response).to be_an_instance_of(Hash)
                  expect(json_response['data']['attributes']['status']).to eq('INITIAL_REVIEW')
                end
              end
            end
          end
        end

        context 'when a phaseback to Under Review status is received' do
          let(:bgs_claim) { build(:bgs_response_with_phaseback_lc_status).to_h }

          it "the v2 mapper sets the 'status' correctly" do
            mock_ccg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
                VCR.use_cassette('claims_api/evss/documents/get_claim_documents') do
                  expect_any_instance_of(bnft_claim_web_service)
                    .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim)
                  expect(ClaimsApi::AutoEstablishedClaim)
                    .to receive(:get_by_id_and_icn).and_return(nil)

                  get claim_by_id_path, headers: auth_header

                  json_response = JSON.parse(response.body)
                  expect(response).to have_http_status(:ok)
                  expect(json_response).to be_an_instance_of(Hash)
                  expect(json_response['data']['attributes']['status']).to eq('INITIAL_REVIEW')
                  expect(json_response['data']['attributes']['claimPhaseDates']['currentPhaseBack']).to be(true)
                  expect(json_response['data']['attributes']['claimPhaseDates']['latestPhaseType'])
                    .to eq('UNDER_REVIEW')
                end
              end
            end
          end
        end

        context 'when there are several phases and one does not have a date' do
          let(:bgs_claim_with_many_phases) { build(:bgs_response_with_lc_status) }

          it 'gracefully handles a nil date' do
            mock_ccg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
                VCR.use_cassette('claims_api/evss/documents/get_claim_documents') do
                  bgs_claim_with_many_phases[:benefit_claim_details_dto][:bnft_claim_lc_status][0][:phase_type_change_ind] = nil # rubocop:disable Layout/LineLength
                  expect_any_instance_of(bnft_claim_web_service)
                    .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim_with_many_phases)
                  expect(ClaimsApi::AutoEstablishedClaim)
                    .to receive(:get_by_id_and_icn).and_return(nil)

                  get claim_by_id_path, headers: auth_header

                  json_response = JSON.parse(response.body)
                  prev_phases = json_response['data']['attributes']['claimPhaseDates']['previousPhases']
                  expect(response).to have_http_status(:ok)
                  expect(prev_phases).to eq({})
                end
              end
            end
          end
        end

        context 'it picks the newest status' do
          it "returns a claim with the 'claimId' and 'lighthouseId' set" do
            mock_ccg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
                VCR.use_cassette('claims_api/evss/documents/get_claim_documents') do
                  expect_any_instance_of(bnft_claim_web_service)
                    .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim_response)
                  expect(ClaimsApi::AutoEstablishedClaim)
                    .to receive(:get_by_id_and_icn).and_return(nil)

                  get claim_by_id_path, headers: auth_header

                  json_response = JSON.parse(response.body)
                  expect(response).to have_http_status(:ok)
                  expect(json_response).to be_an_instance_of(Hash)
                  expect(json_response['data']['attributes']['claimType']).to eq('Compensation')
                  expect(json_response['data']['attributes']['status']).to eq('EVIDENCE_GATHERING_REVIEW_DECISION')
                end
              end
            end
          end
        end
      end

      describe 'when handling a BGS claim' do
        context 'it retrieves the contentions list' do
          it 'lists the contentions without leading spaces' do
            lh_claim = create(:auto_established_claim, status: 'PENDING', veteran_icn: veteran_id,
                                                       evss_id: '111111111')
            claim_contentions = bgs_claim_response
            claim_contentions[:benefit_claim_details_dto][:contentions] = ' c1 (New),  c2 (Old), c3 (Unknown)'
            mock_ccg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
                VCR.use_cassette('claims_api/evss/documents/get_claim_documents') do
                  expect_any_instance_of(bnft_claim_web_service)
                    .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(claim_contentions)
                  expect(ClaimsApi::AutoEstablishedClaim)
                    .to receive(:get_by_id_and_icn).and_return(lh_claim)

                  get claim_by_id_path, headers: auth_header

                  json_response = JSON.parse(response.body)
                  expect(response).to have_http_status(:ok)
                  claim_contentions_res = json_response['data']['attributes']['contentions']
                  expect(claim_contentions_res).to eq([{ 'name' => 'c1 (New)' }, { 'name' => 'c2 (Old)' },
                                                       { 'name' => 'c3 (Unknown)' }])
                end
              end
            end
          end

          it 'lists the contentions correctly with extra commas' do
            lh_claim = create(:auto_established_claim, status: 'PENDING', veteran_icn: veteran_id,
                                                       evss_id: '111111111')
            claim_contentions = bgs_claim_response
            claim_contentions[:benefit_claim_details_dto][:contentions] =
              'Low back strain (New), Knee, internal derangement (New)'
            mock_ccg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
                VCR.use_cassette('claims_api/evss/documents/get_claim_documents') do
                  expect_any_instance_of(bnft_claim_web_service)
                    .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(claim_contentions)
                  expect(ClaimsApi::AutoEstablishedClaim)
                    .to receive(:get_by_id_and_icn).and_return(lh_claim)

                  get claim_by_id_path, headers: auth_header

                  json_response = JSON.parse(response.body)
                  expect(response).to have_http_status(:ok)
                  claim_contentions_res = json_response['data']['attributes']['contentions']
                  expect(claim_contentions_res).to eq([{ 'name' => 'Low back strain (New)' },
                                                       { 'name' => 'Knee, internal derangement (New)' }])
                end
              end
            end
          end
        end
      end

      describe "handling the 'supporting_documents'" do
        context 'it has documents' do
          it "returns a claim with 'supporting_documents'" do
            mock_ccg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/v2/claims_show') do
                allow_any_instance_of(ClaimsApi::V2::ClaimsRequests::SupportingDocuments).to receive(
                  :get_file_number
                ).and_return(file_number)

                expect_any_instance_of(ClaimsApi::V2::BenefitsDocuments::Service)
                  .to receive(:get_auth_token).and_return('some-value-here')
                expect(ClaimsApi::AutoEstablishedClaim)
                  .to receive(:get_by_id_and_icn).and_return(nil)

                get claim_by_id_path, headers: auth_header

                json_response = JSON.parse(response.body)

                first_doc_id = json_response['data']['attributes'].dig('supportingDocuments', 0, 'documentId')
                expect(response).to have_http_status(:ok)
                expect(json_response).to be_an_instance_of(Hash)
                expect(json_response['data']['attributes']['claimType']).to eq('Compensation')
                expect(first_doc_id).to eq('6A40E389-EB12-473C-8C23-D1D6C996C544')
              end
            end
          end
        end

        context 'date fields on supporting docs' do
          it 'adds the uploadDateTime as UTC date format' do
            mock_ccg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/v2/claims_show') do
                allow_any_instance_of(ClaimsApi::V2::ClaimsRequests::SupportingDocuments).to receive(
                  :get_file_number
                ).and_return(file_number)
                expect_any_instance_of(ClaimsApi::V2::BenefitsDocuments::Service)
                  .to receive(:get_auth_token).and_return('some-value-here')
                expect(ClaimsApi::AutoEstablishedClaim)
                  .to receive(:get_by_id_and_icn).and_return(nil)

                get claim_by_id_path, headers: auth_header

                json_response = JSON.parse(response.body)
                first_doc = json_response['data']['attributes'].dig('supportingDocuments', 0)
                expect(first_doc['uploadDateTime']).to eq('2023-04-14T13:55:00Z')
              end
            end
          end
        end

        context 'it has no documents' do
          let(:bgs_claim) { build(:bgs_response_with_one_lc_status).to_h }

          it "returns a claim with 'supporting_documents' as an empty array" do
            bgs_claim[:benefit_claim_details_dto][:benefit_claim_id] = '222222222'

            mock_ccg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
                VCR.use_cassette('claims_api/evss/documents/get_claim_documents') do
                  expect_any_instance_of(bnft_claim_web_service)
                    .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim)
                  expect(ClaimsApi::AutoEstablishedClaim)
                    .to receive(:get_by_id_and_icn).and_return(nil)

                  get claim_by_id_path, headers: auth_header

                  json_response = JSON.parse(response.body)
                  expect(response).to have_http_status(:ok)
                  expect(json_response).to be_an_instance_of(Hash)
                  expect(json_response['data']['attributes']['claimType']).to eq('Compensation')
                  expect(json_response['data']['attributes']['supportingDocuments']).to be_empty
                end
              end
            end
          end
        end

        context 'it has no bgs_claim' do
          let(:lighthouse_claim) do
            create(:auto_established_claim, status: 'PENDING', veteran_icn: '1013062086V794840',
                                            evss_id: '111111111')
          end
          let(:matched_claim_veteran_path) do
            "/services/claims/v2/veterans/#{lighthouse_claim.veteran_icn}/claims/#{lighthouse_claim.id}"
          end
          let(:bgs_claim) { nil }

          it "returns a claim with 'supporting_documents' as an empty array" do
            mock_ccg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
                expect_any_instance_of(bnft_claim_web_service)
                  .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim)

                get matched_claim_veteran_path, headers: auth_header

                json_response = JSON.parse(response.body)
                expect(response).to have_http_status(:ok)
                expect(json_response).to be_an_instance_of(Hash)
                expect(json_response['data']['attributes']['supportingDocuments']).to be_empty
              end
            end
          end
        end

        context 'it has an errors array' do
          let(:claim) do
            create(
              :auto_established_claim,
              :errored,
              source: 'abraham lincoln',
              veteran_icn: veteran_id,
              evss_response: [
                {
                  severity: 'ERROR',
                  detail: 'Something happened',
                  key: 'test.path.here'
                }
              ]
            )
          end
          let(:claim_by_id_path) { "/services/claims/v2/veterans/#{claim.veteran_icn}/claims/#{claim.id}" }

          it "returns a claim with the 'errors' attribute populated" do
            mock_ccg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/evss/claims/claims') do
                get claim_by_id_path, headers: auth_header

                json_response = JSON.parse(response.body)
                expect(response).to have_http_status(:ok)
                expect(json_response['data']['attributes'].dig('errors', 0, 'detail')).to eq('ERROR Something happened')
                expect(json_response['data']['attributes'].dig('errors', 0, 'source')).to eq('test/path/here')
                expect(json_response['data']['attributes']['status']).to eq('ERRORED')
              end
            end
          end
        end
      end

      describe 'ICN' do
        context 'when not found' do
          let(:ccg_token) { OpenStruct.new(client_credentials_token?: true, payload: { 'scp' => [] }) }

          it 'returns a 404' do
            mock_ccg(scopes) do |auth_header|
              allow_any_instance_of(MPIData)
                .to receive(:mvi_response).and_return(profile_erroneous_icn)

              get "/services/claims/v2/veterans/#{profile_erroneous_icn.profile.icn}/claims/#{claim_id}",
                  headers: auth_header

              expect(response).to have_http_status(:not_found)
              json_response = JSON.parse(response.body)
              expect(json_response['errors'][0]['detail']).to eq(
                "Unable to locate Veteran's ID/ICN in Master Person Index (MPI). " \
                'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.'
              )
            end
          end
        end
      end

      describe "handling the 'tracked_items'" do
        context 'it has tracked items' do
          let(:claim_id_with_items) { '600236068' }
          let(:claim_by_id_with_items_path) do
            "/services/claims/v2/veterans/#{veteran_id}/claims/#{claim_id_with_items}"
          end

          it "returns a claim with 'tracked_items'" do
            mock_ccg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/evss/documents/get_claim_documents') do
                VCR.use_cassette('claims_api/bgs/tracked_item_service/claims_v2_show_tracked_items') do
                  allow(ClaimsApi::AutoEstablishedClaim).to receive(:get_by_id_and_icn)

                  get claim_by_id_with_items_path, headers: auth_header

                  json_response = JSON.parse(response.body)
                  first_doc_id = json_response['data']['attributes'].dig('trackedItems', 0, 'id')
                  resp_tracked_items = json_response['data']['attributes']['trackedItems']
                  expect(response).to have_http_status(:ok)
                  expect(json_response['data']['id']).to eq(claim_id_with_items)
                  expect(first_doc_id).to eq(293_439)
                  expect(resp_tracked_items[1]['description']).to be_nil
                  expect(resp_tracked_items[2]['description']).to start_with('On your application,')
                  expect(json_response['data']['attributes']['trackedItems'][0]['displayName']).to eq(
                    'STRs not available - substitute documents needed'
                  )
                  expect(json_response['data']['attributes']['trackedItems'][8]['displayName']).to eq(
                    'Submit buddy statement(s)'
                  )
                  expect(json_response['data']['attributes']['trackedItems'][2]['requestedDate']).to eq(
                    '2021-05-05'
                  )
                  expect(json_response['data']['attributes']['trackedItems'][0]['overdue']).to be(true)
                  expect(json_response['data']['attributes']['trackedItems'][1]['overdue']).to be(false)
                end
              end
            end
          end
        end

        context 'it has tracked items that show SUBMITTED_AWAITING_REVIEW when it should' do
          let(:claim_id_with_items) { '600236068' }
          let(:claim_by_id_with_items_path) do
            "/services/claims/v2/veterans/#{veteran_id}/claims/#{claim_id_with_items}"
          end

          it "returns a claim with 'tracked_items'" do
            mock_ccg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/tracked_item_service/get_claim_documents_with_tracked_item_ids') do
                VCR.use_cassette('claims_api/bgs/tracked_item_service/claims_v2_show_tracked_items') do
                  allow(ClaimsApi::AutoEstablishedClaim).to receive(:get_by_id_and_icn)
                  allow_any_instance_of(ClaimsApi::V2::ClaimsRequests::SupportingDocuments).to receive(
                    :get_file_number
                  ).and_return('123456789')

                  get claim_by_id_with_items_path, headers: auth_header

                  json_response = JSON.parse(response.body)

                  first_doc_id = json_response['data']['attributes'].dig('trackedItems', 0, 'id')
                  resp_tracked_items = json_response['data']['attributes']['trackedItems']
                  expect(response).to have_http_status(:ok)
                  expect(json_response['data']['id']).to eq(claim_id_with_items)
                  expect(first_doc_id).to eq(293_439)
                  expect(resp_tracked_items[0]['status']).to eq('NEEDED_FROM_YOU')
                end
              end
            end
          end
        end

        context 'it has no bgs_claim' do
          let(:lighthouse_claim) do
            create(:auto_established_claim, status: 'PENDING', veteran_icn: '1013062086V794840',
                                            evss_id: '111111111')
          end
          let(:matched_claim_veteran_path) do
            "/services/claims/v2/veterans/#{lighthouse_claim.veteran_icn}/claims/#{lighthouse_claim.id}"
          end
          let(:bgs_claim) { nil }

          it "returns a claim with 'tracked_items' as an empty array" do
            mock_ccg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
                expect_any_instance_of(bnft_claim_web_service)
                  .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim)

                get matched_claim_veteran_path, headers: auth_header

                json_response = JSON.parse(response.body)
                expect(response).to have_http_status(:ok)
                expect(json_response).to be_an_instance_of(Hash)
                expect(json_response['data']['attributes']['trackedItems']).to be_empty
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
              VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
                mock_ccg(scopes) do |auth_header|
                  expect(ClaimsApi::AutoEstablishedClaim)
                    .to receive(:get_by_id_and_icn).and_return(lighthouse_claim)
                  expect_any_instance_of(bnft_claim_web_service)
                    .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(nil)

                  get claim_by_id_path, headers: auth_header
                  expect(response).to have_http_status(:ok)
                end
              end
            end
          end

          context 'when not valid' do
            it 'returns a 401' do
              mock_ccg(scopes) do |auth_header|
                allow_any_instance_of(ClaimsApi::ValidatedToken).to receive(:validated_token_data).and_return(nil)

                get claim_by_id_path, headers: auth_header
                expect(response).to have_http_status(:unauthorized)
              end
            end
          end
        end

        context 'scopes' do
          let(:invalid_scopes) { %w[system/526-pdf.override] }
          let(:claims_show_scopes) { %w[system/claim.read] }

          context 'claims show' do
            it 'returns a 200 response when successful' do
              VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
                mock_ccg_for_fine_grained_scope(claims_show_scopes) do |auth_header|
                  expect(ClaimsApi::AutoEstablishedClaim)
                    .to receive(:get_by_id_and_icn).and_return(lighthouse_claim)
                  expect_any_instance_of(bnft_claim_web_service)
                    .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(nil)
                  get claim_by_id_path, headers: auth_header

                  expect(response).to have_http_status(:ok)
                end
              end
            end

            it 'returns a 401 unauthorized with incorrect scopes' do
              mock_ccg_for_fine_grained_scope(invalid_scopes) do |auth_header|
                get claim_by_id_path, headers: auth_header
                expect(response).to have_http_status(:unauthorized)
              end
            end
          end
        end
      end
    end
  end
end
