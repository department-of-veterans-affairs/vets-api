# frozen_string_literal: true

require 'rails_helper'
require 'bd/bd'

Rspec.describe ClaimsApi::DependentClaimantVerificationService do
  describe '#validate_dependent_by_participant_id!' do
    let(:valid_participant_id_one_dependent) { 600052699 } # rubocop:disable Style/NumericLiterals
    let(:valid_participant_id_two_dependents) { 600049324 } # rubocop:disable Style/NumericLiterals

    before do
      allow(Flipper).to receive(:enabled?).with(:claims_api_use_person_web_service).and_return true
      allow_any_instance_of(ClaimsApi::V2::BenefitsDocuments::Service)
        .to receive(:get_auth_token).and_return('some-value-here')
    end

    context 'when the claimant name belongs to a participantʼs (one) dependent' do
      let(:valid_first_name) { 'margie' } # case should not matter
      let(:valid_last_name) { 'CURTIS' }

      subject do
        described_class.new(veteran_participant_id: valid_participant_id_one_dependent,
                            claimant_first_name: valid_first_name, claimant_last_name: valid_last_name)
      end

      it 'returns nil and does not raise an error' do
        VCR.use_cassette('claims_api/bgs/person_web_service/find_dependents_by_ptcpnt_id_one_dependent') do
          expect do
            ret = subject.validate_dependent_by_participant_id!
            expect(ret).to be_nil
          end.not_to raise_error
        end
      end
    end

    context 'when the claimant name does not belong to a participantʼs (one) dependent' do
      subject do
        described_class.new(veteran_participant_id: valid_participant_id_one_dependent, claimant_first_name: 'BAD',
                            claimant_last_name: 'NAME')
      end

      it 'raises an error' do
        VCR.use_cassette('claims_api/bgs/person_web_service/find_dependents_by_ptcpnt_id_one_dependent') do
          expect do
            subject.validate_dependent_by_participant_id!
          end.to raise_error(Common::Exceptions::UnprocessableEntity)
        end
      end
    end

    context 'when the claimant name belongs to one of participantʼs (many) dependents' do
      let(:valid_first_name) { 'MARK' }
      let(:valid_last_name) { ' bailey ' } # case and whitespace should not matter

      subject do
        described_class.new(veteran_participant_id: valid_participant_id_two_dependents,
                            claimant_first_name: valid_first_name, claimant_last_name: valid_last_name)
      end

      it 'returns nil and does not raise an error' do
        VCR.use_cassette('claims_api/bgs/person_web_service/find_dependents_by_ptcpnt_id_two_dependents') do
          expect do
            ret = subject.validate_dependent_by_participant_id!
            expect(ret).to be_nil
          end.not_to raise_error
        end
      end
    end

    context 'when the claimant name does not belong to one of participantʼs (many) dependents' do
      subject do
        described_class.new(veteran_participant_id: valid_participant_id_two_dependents, claimant_first_name: 'bad',
                            claimant_last_name: 'name')
      end

      it 'raises an error' do
        VCR.use_cassette('claims_api/bgs/person_web_service/find_dependents_by_ptcpnt_id_two_dependents') do
          expect do
            subject.validate_dependent_by_participant_id!
          end.to raise_error(Common::Exceptions::UnprocessableEntity)
        end
      end
    end

    context 'when the claimant provides a valid participant_id of claimantʼs dependent' do
      let(:valid_claimant_participant_id) { 600052700 } # rubocop:disable Style/NumericLiterals

      subject do
        described_class.new(veteran_participant_id: valid_participant_id_one_dependent, claimant_first_name: 'any',
                            claimant_last_name: 'name', claimant_participant_id: valid_claimant_participant_id)
      end

      it 'returns nil and does not raise an error regardless of name' do
        VCR.use_cassette('claims_api/bgs/person_web_service/find_dependents_by_ptcpnt_id_one_dependent') do
          expect do
            ret = subject.validate_dependent_by_participant_id!
            expect(ret).to be_nil
          end.not_to raise_error
        end
      end
    end

    context 'when the claimant provides an invalid participant_id but a valid first and last name' do
      let(:valid_first_name) { 'MARGIE' }
      let(:valid_last_name) { 'CURTIS' }

      subject do
        described_class.new(veteran_participant_id: valid_participant_id_one_dependent,
                            claimant_first_name: valid_first_name, claimant_last_name: valid_last_name,
                            claimant_participant_id: 'bad')
      end

      it 'raises an error' do
        VCR.use_cassette('claims_api/bgs/person_web_service/find_dependents_by_ptcpnt_id_one_dependent') do
          expect do
            subject.validate_dependent_by_participant_id!
          end.to raise_error(Common::Exceptions::UnprocessableEntity)
        end
      end
    end

    # NOTE: This test is the same as the first test but with a different description to emphasize that
    # we will fall back to name matching if the claimant_participant_id is not provided.
    context 'when the claimant provides no claimant_participant_id but a valid first and last name' do
      let(:valid_first_name) { 'MARGIE' }
      let(:valid_last_name) { 'CURTIS' }

      subject do
        described_class.new(veteran_participant_id: valid_participant_id_one_dependent,
                            claimant_first_name: valid_first_name, claimant_last_name: valid_last_name)

        it 'returns nil and does not raise an error' do
          VCR.use_cassette('claims_api/bgs/person_web_service/find_dependents_by_ptcpnt_id_one_dependent') do
            expect do
              ret = subject.validate_dependent_by_participant_id!
              expect(ret).to be_nil
            end.not_to raise_error
          end
        end
      end
    end

    context 'when the participant_id is invalid or has no dependents' do
      subject do
        described_class.new(veteran_participant_id: 'bad', claimant_first_name: 'any', claimant_last_name: 'name')
      end

      it 'raises an error' do
        VCR.use_cassette('claims_api/bgs/person_web_service/find_dependents_by_ptcpnt_id_no_dependents') do
          expect do
            subject.validate_dependent_by_participant_id!
          end.to raise_error(Common::Exceptions::UnprocessableEntity)
        end
      end
    end

    context 'when the participant_id is blank' do
      subject do
        described_class.new(veteran_participant_id: '', claimant_first_name: 'any', claimant_last_name: 'name')
      end

      it 'raises an error' do
        expect do
          subject.validate_dependent_by_participant_id!
        end.to raise_error(Common::Exceptions::UnprocessableEntity)
      end
    end

    context 'when the participant_id is nil' do
      subject do
        described_class.new(veteran_participant_id: nil, claimant_first_name: 'any', claimant_last_name: 'name')
      end

      it 'raises an error' do
        expect do
          subject.validate_dependent_by_participant_id!
        end.to raise_error(Common::Exceptions::UnprocessableEntity)
      end
    end
  end

  describe '#validate_poa_code_exists!' do
    let(:valid_poa_code) { '002' }

    subject { described_class.new(poa_code: valid_poa_code) }

    context 'when the poa_code is valid' do
      it 'returns nil and does not raise an error' do
        VCR.use_cassette('claims_api/bgs/standard_data_web_service/find_poas') do
          expect do
            ret = subject.validate_poa_code_exists!
            expect(ret).to be_nil
          end.not_to raise_error
        end
      end
    end

    context 'when the poa_code is invalid' do
      subject { described_class.new(poa_code: 'bad') }

      it 'raises an error' do
        VCR.use_cassette('claims_api/bgs/standard_data_web_service/find_poas') do
          expect do
            subject.validate_poa_code_exists!
          end.to raise_error(Common::Exceptions::UnprocessableEntity)
        end
      end
    end

    context 'when the poa_code is blank' do
      subject { described_class.new(poa_code: '') }

      it 'raises an error' do
        expect do
          subject.validate_poa_code_exists!
        end.to raise_error(Common::Exceptions::UnprocessableEntity)
      end
    end

    context 'when the poa_code is nil' do
      subject { described_class.new(poa_code: nil) }

      it 'raises an error' do
        expect do
          subject.validate_poa_code_exists!
        end.to raise_error(Common::Exceptions::UnprocessableEntity)
      end
    end
  end
end
