# frozen_string_literal: true

require 'rails_helper'

Rspec.describe ClaimsApi::DependentClaimantVerificationService do
  describe '#validate_dependent_by_participant_id!' do
    let(:valid_participant_id_one_dependent) { 600052699 } # rubocop:disable Style/NumericLiterals
    let(:valid_participant_id_two_dependents) { 600049324 } # rubocop:disable Style/NumericLiterals

    context 'when the dependent name belongs to a participant with one dependent' do
      let(:valid_first_name) { 'margie' } # case should not matter
      let(:valid_last_name) { 'CURTIS' }

      subject { described_class.new(valid_participant_id_one_dependent, valid_first_name, valid_last_name, nil) }

      it 'returns nil and does not raise an error' do
        VCR.use_cassette('claims_api/bgs/person_web_service/find_dependents_by_ptcpnt_id_one_dependent') do
          expect do
            ret = subject.validate_dependent_by_participant_id!
            expect(ret).to eq(nil)
          end.not_to raise_error
        end
      end
    end

    context 'when the dependent name does not belong to a participant with one dependent' do
      subject { described_class.new(valid_participant_id_one_dependent, 'BAD', 'NAME', nil) }

      it 'raises an error' do
        VCR.use_cassette('claims_api/bgs/person_web_service/find_dependents_by_ptcpnt_id_one_dependent') do
          expect do
            subject.validate_dependent_by_participant_id!
          end.to raise_error(Common::Exceptions::UnprocessableEntity)
        end
      end
    end

    context 'when the dependent name belongs to a participant with two dependents' do
      let(:valid_first_name) { 'MARK' }
      let(:valid_last_name) { ' bailey ' } # case and whitespace should not matter

      subject { described_class.new(valid_participant_id_two_dependents, valid_first_name, valid_last_name, nil) }

      it 'returns nil and does not raise an error' do
        VCR.use_cassette('claims_api/bgs/person_web_service/find_dependents_by_ptcpnt_id_two_dependents') do
          expect do
            ret = subject.validate_dependent_by_participant_id!
            expect(ret).to eq(nil)
          end.not_to raise_error
        end
      end
    end

    context 'when the dependent name does not belong to a participant with two dependents' do
      subject { described_class.new(valid_participant_id_two_dependents, 'bad', 'name', nil) }

      it 'raises an error' do
        VCR.use_cassette('claims_api/bgs/person_web_service/find_dependents_by_ptcpnt_id_two_dependents') do
          expect do
            subject.validate_dependent_by_participant_id!
          end.to raise_error(Common::Exceptions::UnprocessableEntity)
        end
      end
    end

    context 'when the participant_id is invalid or has no dependents' do
      subject { described_class.new(123, 'any', 'name', nil) }

      it 'raises an error' do
        VCR.use_cassette('claims_api/bgs/person_web_service/find_dependents_by_ptcpnt_id_no_dependents') do
          expect do
            subject.validate_dependent_by_participant_id!
          end.to raise_error(Common::Exceptions::UnprocessableEntity)
        end
      end
    end

    context 'when the participant_id is blank' do
      subject { described_class.new('', 'any', 'name', nil) }

      it 'raises an error' do
        expect do
          subject.validate_dependent_by_participant_id!
        end.to raise_error(Common::Exceptions::UnprocessableEntity)
      end
    end

    context 'when the participant_id is nil' do
      subject { described_class.new(nil, 'any', 'name', nil) }

      it 'raises an error' do
        expect do
          subject.validate_dependent_by_participant_id!
        end.to raise_error(Common::Exceptions::UnprocessableEntity)
      end
    end
  end

  describe '#validate_poa_code_exists!' do
    let(:valid_poa_code) { '002' }

    subject { described_class.new(nil, nil, nil, valid_poa_code) }

    context 'when the poa_code is valid' do
      it 'returns nil and does not raise an error' do
        VCR.use_cassette('claims_api/bgs/standard_data_web_service/find_poas') do
          expect do
            ret = subject.validate_poa_code_exists!
            expect(ret).to eq(nil)
          end.not_to raise_error
        end
      end
    end

    context 'when the poa_code is invalid' do
      subject { described_class.new(nil, nil, nil, 'bad') }

      it 'raises an error' do
        VCR.use_cassette('claims_api/bgs/standard_data_web_service/find_poas') do
          expect do
            subject.validate_poa_code_exists!
          end.to raise_error(Common::Exceptions::UnprocessableEntity)
        end
      end
    end

    context 'when the poa_code is blank' do
      subject { described_class.new(nil, nil, nil, '') }

      it 'raises an error' do
        expect do
          subject.validate_poa_code_exists!
        end.to raise_error(Common::Exceptions::UnprocessableEntity)
      end
    end

    context 'when the poa_code is nil' do
      subject { described_class.new(nil, nil, nil, nil) }

      it 'raises an error' do
        expect do
          subject.validate_poa_code_exists!
        end.to raise_error(Common::Exceptions::UnprocessableEntity)
      end
    end
  end
end
