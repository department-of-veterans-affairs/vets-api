# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::BGSToLighthouseClaimsMapperService do
  describe 'process' do
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
          claims = ClaimsApi::BGSToLighthouseClaimsMapperService.process(
            bgs_claims: bgs_claims, internal_claims: lighthouse_claims
          )

          expect(claims).to be_an_instance_of(Array)
          expect(claims.count).to eq(5) # 3 from bgs collection and 2 from lighthouse collection
          expect(claims.any? { |e| e[:id] == lighthouse_claims.first.id }).to be true
          expect(claims.any? { |e| e[:id] == bgs_claims[:bnft_claim_detail].first[:bnft_claim_id] }).to be false
        end
      end
    end
  end
end
