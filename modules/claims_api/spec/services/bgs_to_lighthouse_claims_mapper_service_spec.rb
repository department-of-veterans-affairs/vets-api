# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::BGSToLighthouseClaimsMapperService do
  describe 'process' do
    context 'when BGS and Lighthouse claims exist' do
      context 'when a BGS claim is also in the Lighthouse collection' do
        let(:bgs_claims) do
          {
            bnft_claim_detail: [
              {
                bnft_claim_id: '111111111',
                bnft_claim_type_nm: 'Appeals Control'
              }
            ]
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

        it 'returns a collection that contains the claim with the Lighthouse id and BGS type' do
          claims = ClaimsApi::BGSToLighthouseClaimsMapperService.process(
            bgs_claims: bgs_claims, lighthouse_claims: lighthouse_claims
          )

          expect(claims.count).to eq(1)
          expect(claims.first[:id]).to eq('0958d973-36fb-43ef-8801-2718bd33c825')
          expect(claims.first[:type]).to eq('Appeals Control')
          expect(claims.any? { |claim| claim[:id] == '111111111' }).to be false
        end
      end

      context 'when a BGS claim is NOT in the Lighthouse collection' do
        let(:bgs_claims) do
          {
            bnft_claim_detail: [
              {
                bnft_claim_id: '111111111',
                bnft_claim_type_nm: 'Appeals Control'
              }
            ]
          }
        end
        let(:lighthouse_claims) do
          [
            OpenStruct.new(
              id: '0958d973-36fb-43ef-8801-2718bd33c825',
              evss_id: '1',
              claim_type: 'Compensation',
              status: 'pending'
            )
          ]
        end

        it 'returns a collection that contains both claims' do
          claims = ClaimsApi::BGSToLighthouseClaimsMapperService.process(
            bgs_claims: bgs_claims, lighthouse_claims: lighthouse_claims
          )

          expect(claims.count).to eq(2)
          expect(claims.any? { |claim| claim[:id] == '111111111' }).to be true
          expect(claims.any? { |claim| claim[:id] == '0958d973-36fb-43ef-8801-2718bd33c825' }).to be true
        end
      end
    end

    context 'when only BGS claims exist' do
      let(:bgs_claims) do
        {
          bnft_claim_detail: [
            {
              bnft_claim_id: '111111111',
              bnft_claim_type_nm: 'Appeals Control'
            }
          ]
        }
      end
      let(:lighthouse_claims) { [] }

      it 'returns a collection that contains the BGS claims' do
        claims = ClaimsApi::BGSToLighthouseClaimsMapperService.process(
          bgs_claims: bgs_claims, lighthouse_claims: lighthouse_claims
        )

        expect(claims.count).to eq(1)
        expect(claims.first[:id]).to eq('111111111')
        expect(claims.first[:type]).to eq('Appeals Control')
      end
    end

    context 'when only Lighthouse claims exist' do
      let(:bgs_claims) do
        {
          bnft_claim_detail: []
        }
      end

      let(:lighthouse_claims) do
        [
          OpenStruct.new(
            id: '0958d973-36fb-43ef-8801-2718bd33c825',
            evss_id: '1',
            claim_type: 'Compensation',
            status: 'pending'
          )
        ]
      end

      it 'returns a collection that contains the Lighthouse claims' do
        claims = ClaimsApi::BGSToLighthouseClaimsMapperService.process(
          bgs_claims: bgs_claims, lighthouse_claims: lighthouse_claims
        )

        expect(claims.count).to eq(1)
        expect(claims.first[:id]).to eq('0958d973-36fb-43ef-8801-2718bd33c825')
        expect(claims.first[:type]).to eq('Compensation')
      end
    end

    context 'when no Lighthouse claims exist and no BGS claims exist' do
      let(:bgs_claims) do
        {
          bnft_claim_detail: []
        }
      end

      let(:lighthouse_claims) { [] }

      it 'returns an empty collection' do
        claims = ClaimsApi::BGSToLighthouseClaimsMapperService.process(
          bgs_claims: bgs_claims, lighthouse_claims: lighthouse_claims
        )

        expect(claims.count).to eq(0)
      end
    end

    context "'established' Lighthouse claims" do
      context "when an 'established' Lighthouse claim is unknown to BGS" do
        let(:bgs_claims) do
          {
            bnft_claim_detail: [
              {
                bnft_claim_id: '111111111',
                bnft_claim_type_nm: 'Appeals Control'
              }
            ]
          }
        end
        let(:lighthouse_claims) do
          [
            OpenStruct.new(
              id: '0958d973-36fb-43ef-8801-2718bd33c825',
              evss_id: '111111111',
              claim_type: 'Compensation',
              status: 'established'
            ),
            OpenStruct.new(
              id: '55555555-5555-5555-5555-555555555555',
              evss_id: '1',
              claim_type: 'Compensation',
              status: 'established'
            )
          ]
        end

        it "returns a collection that does not contain the 'established' Lighthouse claim" do
          claims = ClaimsApi::BGSToLighthouseClaimsMapperService.process(
            bgs_claims: bgs_claims, lighthouse_claims: lighthouse_claims
          )

          expect(claims.count).to eq(1)
          expect(claims.first[:id]).to eq('0958d973-36fb-43ef-8801-2718bd33c825')
          expect(claims.first[:type]).to eq('Appeals Control')
          expect(claims.any? { |claim| claim[:id] == '55555555-5555-5555-5555-555555555555' }).to be false
        end
      end
    end
  end
end
