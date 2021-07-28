# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::BGSToLighthouseClaimsMapperService do
  describe 'process' do
    context 'when BGS and Lighthouse claim provided' do
      let(:bgs_claim) do
        {
          benefit_claim_id: '111111111',
          claim_status_type: 'Compensation'
        }
      end
      let(:lighthouse_claim) do
        OpenStruct.new(
          id: '0958d973-36fb-43ef-8801-2718bd33c825',
          evss_id: '111111111',
          claim_type: 'Compensation',
          status: 'pending'
        )
      end

      it "returns a claim that has the Lighthouse 'id'" do
        claim = ClaimsApi::BGSToLighthouseClaimsMapperService.process(
          bgs_claim: bgs_claim, lighthouse_claim: lighthouse_claim
        )

        expect(claim[:id]).to eq('0958d973-36fb-43ef-8801-2718bd33c825')
      end
    end

    context 'when only BGS claim is provided' do
      let(:bgs_claim) do
        {
          benefit_claim_id: '111111111',
          claim_status_type: 'Compensation'
        }
      end

      it "returns a claim that has the BGS 'id'" do
        claim = ClaimsApi::BGSToLighthouseClaimsMapperService.process(
          bgs_claim: bgs_claim
        )

        expect(claim[:id]).to eq('111111111')
      end
    end

    context 'when only Lighthouse claim is provided' do
      let(:lighthouse_claim) do
        OpenStruct.new(
          id: '0958d973-36fb-43ef-8801-2718bd33c825',
          evss_id: '111111111',
          claim_type: 'Compensation',
          status: 'pending'
        )
      end

      it "returns a claim that has the Lighthouse 'id'" do
        claim = ClaimsApi::BGSToLighthouseClaimsMapperService.process(
          lighthouse_claim: lighthouse_claim
        )

        expect(claim[:id]).to eq('0958d973-36fb-43ef-8801-2718bd33c825')
      end
    end

    context 'when neither BGS claim, nor Lighthouse claim is provided' do
      it 'returns an empty hash' do
        claim = ClaimsApi::BGSToLighthouseClaimsMapperService.process

        expect(claim).to eq({})
      end
    end
  end
end
