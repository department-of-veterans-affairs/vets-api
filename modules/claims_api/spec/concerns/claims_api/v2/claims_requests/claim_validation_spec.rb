# frozen_string_literal: true

require 'rails_helper'
require 'bd/bd'

class FakeController
  include ClaimsApi::V2::ClaimsRequests::ClaimValidation

  def target_veteran
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
end

describe ClaimsApi::V2::ClaimsRequests::ClaimValidation do
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

  let(:dependent_target_veteran) do
    OpenStruct.new(
      icn: '1012861229V078999',
      first_name: 'Janet',
      last_name: 'Moore',
      loa: { current: 3, highest: 3 },
      ssn: '796127677',
      edipi: '8040545646',
      participant_id: '600987654',
      mpi: OpenStruct.new(
        icn: '1012861229V078999',
        profile: OpenStruct.new(ssn: '796127677')
      )
    )
  end

  let(:controller) { FakeController.new }

  let(:vet_request_icn) { target_veteran.icn }
  let(:claimant_request_icn) { target_veteran.icn }
  let(:bgs_claim_for_target_veteran) do
    { benefit_claim_details_dto: { ptcpnt_vet_id: '600061742', ptcpnt_clmant_id: '600987654' } }
  end
  let(:bgs_claim_for_dependent) do
    { benefit_claim_details_dto: { ptcpnt_vet_id: '600061742', ptcpnt_clmant_id: '600987654' } }
  end
  let(:inaccessable_bgs_claim) do
    { benefit_claim_details_dto: { ptcpnt_vet_id: '999999999', ptcpnt_clmant_id: '888888888' } }
  end

  describe '#validate_id_with_icn' do
    context 'when the claim is being accessed by the veteran' do
      let(:request_icn) { vet_request_icn }
      let(:bgs_claim) { bgs_claim_for_target_veteran }
      let(:lighthouse_claim) { { 'veteran_icn' => target_veteran.icn } }

      it 'does not raise an error' do
        expect { controller.validate_id_with_icn(bgs_claim, lighthouse_claim, request_icn) }.not_to raise_error
      end
    end

    context 'when the claim is being accessed by the dependent' do
      let(:request_icn) { claimant_request_icn }
      let(:lighthouse_claim) { { 'veteran_icn' => '1012861229V078999' } }
      let(:bgs_claim) { bgs_claim_for_dependent }

      it 'does not raise an error' do
        expect { controller.validate_id_with_icn(bgs_claim, lighthouse_claim, request_icn) }.not_to raise_error
      end
    end

    context 'when the claim cannot be accessed by the veteran or the dependent' do
      let(:request_icn) { vet_request_icn }
      let(:lighthouse_claim) { { 'veteran_icn' => '1012845028V591299' } }
      let(:bgs_claim) { inaccessable_bgs_claim }

      # rubocop:disable Style/MultilineBlockChain
      it 'raises a ResourceNotFound error' do
        expect do
          controller.validate_id_with_icn(bgs_claim, lighthouse_claim, request_icn)
        end.to raise_error(Common::Exceptions::ResourceNotFound) do |error|
          expect(error.errors[0].detail).to eq('Invalid claim ID for the veteran identified.')
        end
      end
      # rubocop:enable Style/MultilineBlockChain
    end
  end

  describe '#clm_prtcpnt_cannot_access_claim?' do
    let(:request_icn) { vet_request_icn }
    let(:bgs_claim) { bgs_claim_for_target_veteran }
    let(:lighthouse_claim) { { 'veteran_icn' => target_veteran.icn } }
    let(:ptcpnt_id) { target_veteran.participant_id }

    context 'when either vet_id or claimant_id is nil' do
      it 'returns true' do
        expect(controller.send(:clm_prtcpnt_cannot_access_claim?, nil, ptcpnt_id)).to be true
        expect(controller.send(:clm_prtcpnt_cannot_access_claim?, ptcpnt_id, nil)).to be true
      end
    end

    context 'when both vet_id and claimant_id match the target veteran' do
      it 'returns false' do
        expect(controller.send(:clm_prtcpnt_cannot_access_claim?, ptcpnt_id, ptcpnt_id)).to be false
      end
    end

    context 'when vet_id does not match and claimant_id does not match the target veteran' do
      it 'returns true' do
        expect(controller.send(:clm_prtcpnt_cannot_access_claim?, 'vet_id', 'claimant_id')).to be true
      end
    end

    context 'when vet_id matches and claimant_id does not match the target veteran' do
      it 'returns false' do
        expect(controller.send(:clm_prtcpnt_cannot_access_claim?, ptcpnt_id, 'claimant_id')).to be false
      end
    end

    context 'when claimant_id matches and vet_id does not match the target veteran' do
      it 'returns false' do
        expect(controller.send(:clm_prtcpnt_cannot_access_claim?, 'vet_id', ptcpnt_id)).to be false
      end
    end
  end
end
