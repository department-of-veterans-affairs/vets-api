# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/person_web_service'

class FakeController < ApplicationController
  include ClaimsApi::DependentClaimantVerification
end

describe FakeController do
  describe '#validate_dependent_by_participant_id!' do
    let(:valid_participant_id_one_dependent) { 600052699 } # rubocop:disable Style/NumericLiterals
    let(:valid_participant_id_two_dependents) { 600049324 } # rubocop:disable Style/NumericLiterals

    context 'when the dependent name belongs to a participant with one dependent' do
      let(:valid_first_name) { 'margie' } # case should not matter
      let(:valid_last_name) { 'CURTIS' }

      it 'returns nil and does not raise an error' do
        VCR.use_cassette('claims_api/bgs/person_web_service/find_dependents_by_ptcpnt_id_one_dependent') do
          expect do
            ret = subject.validate_dependent_by_participant_id!(valid_participant_id_one_dependent, valid_first_name,
                                                                valid_last_name)
            expect(ret).to eq(nil)
          end.not_to raise_error
        end
      end
    end

    context 'when the dependent name does not belong to a participant with one dependent' do
      it 'raises an error' do
        VCR.use_cassette('claims_api/bgs/person_web_service/find_dependents_by_ptcpnt_id_one_dependent') do
          expect do
            subject.validate_dependent_by_participant_id!(valid_participant_id_one_dependent, 'BAD', 'NAME')
          end.to raise_error(Common::Exceptions::UnprocessableEntity)
        end
      end
    end

    context 'when the dependent name belongs to a participant with two dependents' do
      let(:valid_first_name) { 'MARK' }
      let(:valid_last_name) { ' bailey ' } # case and whitespace should not matter

      it 'returns nil and does not raise an error' do
        VCR.use_cassette('claims_api/bgs/person_web_service/find_dependents_by_ptcpnt_id_two_dependents') do
          expect do
            ret = subject.validate_dependent_by_participant_id!(valid_participant_id_two_dependents, valid_first_name,
                                                                valid_last_name)
            expect(ret).to eq(nil)
          end.not_to raise_error
        end
      end
    end

    context 'when the dependent name does not belong to a participant with two dependents' do
      it 'raises an error' do
        VCR.use_cassette('claims_api/bgs/person_web_service/find_dependents_by_ptcpnt_id_two_dependents') do
          expect do
            subject.validate_dependent_by_participant_id!(valid_participant_id_two_dependents, 'bad', 'name')
          end.to raise_error(Common::Exceptions::UnprocessableEntity)
        end
      end
    end

    context 'when the participant_id is invalid or has no dependents' do
      it 'raises an error' do
        VCR.use_cassette('claims_api/bgs/person_web_service/find_dependents_by_ptcpnt_id_no_dependents') do
          expect do
            subject.validate_dependent_by_participant_id!(123, 'any', 'name')
          end.to raise_error(Common::Exceptions::UnprocessableEntity)
        end
      end
    end

    context 'when the participant_id is blank or nil' do
      it 'raises an error' do
        expect do
          subject.validate_dependent_by_participant_id!('', 'any', 'name')
        end.to raise_error(Common::Exceptions::UnprocessableEntity)

        expect do
          subject.validate_dependent_by_participant_id!(nil, 'any', 'name')
        end.to raise_error(Common::Exceptions::UnprocessableEntity)
      end
    end
  end

  describe '#validate_poa_code_by_participant_id!' do
    let(:valid_participant_poa_combo) do
      { ptcpnt_id: '46004', legacy_poa_cd: '002' }
    end

    let(:another_valid_participant_poa_combo) do
      { ptcpnt_id: '46028', legacy_poa_cd: '003' }
    end

    context 'when the participant_id and poa_code are valid' do
      it 'returns nil and does not raise an error' do
        VCR.use_cassette('claims_api/bgs/standard_data_web_service/find_poas') do
          expect do
            ret = subject.validate_poa_code_by_participant_id!(valid_participant_poa_combo[:ptcpnt_id],
                                                               valid_participant_poa_combo[:legacy_poa_cd])
            expect(ret).to eq(nil)

            ret = subject.validate_poa_code_by_participant_id!(another_valid_participant_poa_combo[:ptcpnt_id],
                                                               another_valid_participant_poa_combo[:legacy_poa_cd])
            expect(ret).to eq(nil)
          end.not_to raise_error
        end
      end
    end

    context 'when the participant_id and poa_code are mismatched' do
      it 'raises an error' do
        VCR.use_cassette('claims_api/bgs/standard_data_web_service/find_poas') do
          expect do
            subject.validate_poa_code_by_participant_id!(valid_participant_poa_combo[:ptcpnt_id],
                                                         another_valid_participant_poa_combo[:legacy_poa_cd])
          end.to raise_error(Common::Exceptions::UnprocessableEntity)
        end
      end
    end

    context 'when the participant_id and poa_code are invalid' do
      it 'raises an error' do
        VCR.use_cassette('claims_api/bgs/standard_data_web_service/find_poas') do
          expect do
            subject.validate_poa_code_by_participant_id!(123, 'any')
          end.to raise_error(Common::Exceptions::UnprocessableEntity)
        end
      end
    end

    context 'when the participant_id is blank or nil' do
      it 'raises an error' do
        expect do
          subject.validate_poa_code_by_participant_id!('', 'any')
        end.to raise_error(Common::Exceptions::UnprocessableEntity)

        expect do
          subject.validate_poa_code_by_participant_id!(nil, 'any')
        end.to raise_error(Common::Exceptions::UnprocessableEntity)
      end
    end

    context 'when the poa_code is blank or nil' do
      it 'raises an error' do
        expect do
          subject.validate_poa_code_by_participant_id!(123, '')
        end.to raise_error(Common::Exceptions::UnprocessableEntity)

        expect do
          subject.validate_poa_code_by_participant_id!(123, nil)
        end.to raise_error(Common::Exceptions::UnprocessableEntity)
      end
    end
  end
end
