# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Claims', type: :request do
  let(:veteran_id) { '1013062086V794840' }
  let(:path) { "/services/benefits/v2/veterans/#{veteran_id}/claims" }
  let(:scopes) { %w[claim.read] }

  describe 'Claims' do
    context 'auth header' do
      context 'when provided' do
        it 'returns a 200' do
          with_okta_user(scopes) do |auth_header|
            expect_any_instance_of(BGS::BenefitClaimWebServiceV1)
              .to receive(:find_claims_details_by_participant_id).and_return({ bnft_claim_detail: [] })
            expect(ClaimsApi::AutoEstablishedClaim)
              .to receive(:where).and_return([])

            get path, headers: auth_header
            expect(response.status).to eq(200)
          end
        end
      end

      context 'when not provided' do
        it 'returns a 401 error code' do
          with_okta_user(scopes) do
            get path
            expect(response.status).to eq(401)
          end
        end
      end
    end

    context 'veteran_id param' do
      context 'when not provided' do
        let(:veteran_id) { nil }

        it 'returns a 404 error code' do
          with_okta_user(scopes) do |auth_header|
            get path, headers: auth_header
            expect(response.status).to eq(404)
          end
        end
      end

      context 'when known veteran_id is provided' do
        it 'returns a 200' do
          with_okta_user(scopes) do |auth_header|
            expect_any_instance_of(BGS::BenefitClaimWebServiceV1)
              .to receive(:find_claims_details_by_participant_id).and_return({ bnft_claim_detail: [] })
            expect(ClaimsApi::AutoEstablishedClaim)
              .to receive(:where).and_return([])

            get path, headers: auth_header
            expect(response.status).to eq(200)
          end
        end
      end

      context 'when unknown veteran_id is provided' do
        let(:veteran) { OpenStruct.new(mpi: nil, participant_id: nil) }

        it 'returns a 403 error code' do
          with_okta_user(scopes) do |auth_header|
            expect(ClaimsApi::Veteran).to receive(:new).and_return(veteran)

            get path, headers: auth_header
            expect(response.status).to eq(403)
          end
        end
      end
    end

    context 'mapping claims results' do
      context 'when BGS and Lighthouse claims exist' do
        let(:bgs_claims) do
          {
            bnft_claim_detail: [
              {
                bnft_claim_id: '111111111',
                bnft_claim_type_nm: 'Appeals Control'
              },
              {
                bnft_claim_id: '222222222',
                bnft_claim_type_nm: 'Claim for Increase'
              },
              {
                bnft_claim_id: '333333333',
                bnft_claim_type_nm: 'Rating Control'
              }
            ]
          }
        end
        let(:lighthouse_claims) do
          [
            OpenStruct.new(id: '0958d973-36fb-43ef-8801-2718bd33c825', evss_id: '111111111'),
            OpenStruct.new(id: '16219cf1-0b81-45b1-b07e-ccb01e591164', evss_id: '2'),
            OpenStruct.new(id: '24aa5334-d15d-45f6-a331-1be909494de3', evss_id: '3')
          ]
        end

        it 'returns a combined collection with appropriate identifiers' do
          with_okta_user(scopes) do |auth_header|
            expect_any_instance_of(BGS::BenefitClaimWebServiceV1)
              .to receive(:find_claims_details_by_participant_id).and_return(bgs_claims)
            expect(ClaimsApi::AutoEstablishedClaim)
              .to receive(:where).and_return(lighthouse_claims)

            get path, headers: auth_header
            json_response = JSON.parse(response.body)

            expect(response.status).to eq(200)
            expect(json_response).to be_an_instance_of(Array)
            expect(json_response.count).to eq(5) # 3 from bgs collection and 2 from lighthouse collection
            expect(json_response.any? { |e| e['id'] == lighthouse_claims.first.id }).to be true
            expect(
              json_response.any? do |e|
                e['id'] == bgs_claims[:bnft_claim_detail].first[:bnft_claim_id]
              end
            ).to be false
          end
        end
      end
    end
  end
end
