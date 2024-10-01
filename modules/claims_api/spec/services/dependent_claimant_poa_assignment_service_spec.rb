# frozen_string_literal: true

require 'rails_helper'

Rspec.describe ClaimsApi::DependentClaimantPoaAssignmentService do
  describe '#assign_poa_to_dependent!' do
    let(:service) do
      described_class.new(poa_code: '002', veteran_participant_id: '600052699', dependent_participant_id: '600052700',
                          veteran_file_number: '796163671', claimant_ssn: '796163672')
    end

    context 'when the dependent has no open claims' do
      it 'assigns the POA to the dependent via manage_ptcpnt_rlnshp' do
        VCR.insert_cassette('claims_api/bgs/person_web_service/manage_ptcpnt_rlnshp_poa_no_open_claims')
        VCR.insert_cassette('claims_api/bgs/standard_data_web_service/find_poas')

        allow(service).to receive(:assign_poa_to_dependent_via_manage_ptcpnt_rlnshp?).and_call_original

        expect do
          service.assign_poa_to_dependent!
        end.not_to raise_error

        expect(service).to have_received(:assign_poa_to_dependent_via_manage_ptcpnt_rlnshp?)
      end
    end

    context 'when the dependent has open claims' do
      it 'assigns the POA to the dependent via update_benefit_claim' do
        VCR.insert_cassette('claims_api/bgs/person_web_service/manage_ptcpnt_rlnshp_poa_with_open_claims')
        VCR.insert_cassette('claims_api/bgs/standard_data_web_service/find_poas')
        VCR.insert_cassette(
          'claims_api/bgs/e_benefits_bnft_claim_status_web_service/find_benefit_claims_status_by_ptcpnt_id'
        )
        VCR.insert_cassette('claims_api/bgs/benefit_claim_web_service/find_bnft_claim')
        VCR.insert_cassette('claims_api/bgs/benefit_claim_service/update_benefit_claim')

        allow(service).to receive(:assign_poa_to_dependent_via_update_benefit_claim?).and_call_original

        expect do
          service.assign_poa_to_dependent!
        end.not_to raise_error

        expect(service).to have_received(:assign_poa_to_dependent_via_update_benefit_claim?)
      end
    end
  end
end
