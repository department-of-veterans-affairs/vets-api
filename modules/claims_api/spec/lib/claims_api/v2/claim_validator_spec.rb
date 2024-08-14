# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/v2/claims/claim_validator'

describe ClaimsApi::V2::ClaimValidator do
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
	let(:request_icn) { target_veteran.icn }
	let(:bgs_claim) { { benefit_claim_details_dto: { ptcpnt_vet_id: '600123456', ptcpnt_clmant_id: '600987654' }} }
	let(:lighthouse_claim) { { 'veteran_icn' => target_veteran.icn } }

	subject { ClaimsApi::V2::ClaimValidator.new(bgs_claim, lighthouse_claim, request_icn, target_veteran) }

	describe '#validate!' do
	  context 'when the claim is valid' do
	    it 'does not raise an error' do
	      expect { subject.validate! }.not_to raise_error
	    end
	  end

	  context 'when the claim ID does not match the veteran\'s ICN' do
	    let(:lighthouse_claim) { { 'veteran_icn' => '1012845028V591299' } }

	    it 'raises a ResourceNotFound error' do
	      expect {
	        subject.validate!
	      }.to raise_error(Common::Exceptions::ResourceNotFound, 'Invalid claim ID for the veteran identified.')
	    end
	  end

	  context 'when bgs_claim is missing details' do
	    let(:bgs_claim) { {} }

	    it 'raises a ResourceNotFound error' do
	      expect {
	        subject.validate!
	      }.to raise_error(Common::Exceptions::ResourceNotFound, 'Invalid claim ID for the veteran identified.')
	    end
	  end

	  context 'when the claim participant cannot access the claim' do
	    let(:bgs_claim) { { benefit_claim_details_dto: { ptcpnt_vet_id: 'veteran456', ptcpnt_clmant_id: 'claimant123' }} }

	    it 'raises a ResourceNotFound error' do
	      expect {
	        subject.validate!
	      }.to raise_error(Common::Exceptions::ResourceNotFound, 'Invalid claim ID for the veteran identified.')
	    end
	  end
	end
end
