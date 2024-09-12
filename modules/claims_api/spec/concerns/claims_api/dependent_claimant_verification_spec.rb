# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/person_web_service'

class FakeController < ApplicationController
  include ClaimsApi::DependentClaimantVerification
end

describe FakeController do
  describe '#validate_dependent_by_participant_id!' do
    let(:valid_participant_id) { 600052699 } # rubocop:disable Style/NumericLiterals
    let(:valid_first_name) { 'MARGIE' }
    let(:valid_last_name) { 'CURTIS' }

    context 'when the dependent name is valid' do
      it 'returns nil and does not raise an error' do
        VCR.use_cassette('claims_api/bgs/person_web_service/find_dependents_by_ptcpnt_id') do
          expect do
            ret = subject.validate_dependent_by_participant_id!(valid_participant_id, valid_first_name, valid_last_name)
            expect(ret).to eq(nil)
          end.not_to raise_error
        end
      end
    end

    context 'when the dependent name is invalid' do
      it 'raises an error' do
        VCR.use_cassette('claims_api/bgs/person_web_service/find_dependents_by_ptcpnt_id') do
          expect do
            subject.validate_dependent_by_participant_id!(valid_participant_id, 'BAD', 'NAME')
          end.to raise_error(Common::Exceptions::InvalidFieldValue)
        end
      end
    end

    context 'when the participant_id is invalid or has no dependents' do
      let(:person_web_service) { double(ClaimsApi::PersonWebService) }

      before do
        allow(ClaimsApi::PersonWebService).to receive(:new).and_return(person_web_service)
      end

      it 'raises an error' do
        allow(person_web_service).to receive(:find_dependents_by_ptcpnt_id).with(123).and_return(
          { number_of_records: '0' }
        )

        expect do
          subject.validate_dependent_by_participant_id!(123, valid_first_name, valid_last_name)
        end.to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end

    context 'when the participant_id is blank or nil' do
      it 'raises an error' do
        expect do
          subject.validate_dependent_by_participant_id!('', valid_first_name, valid_last_name)
        end.to raise_error(Common::Exceptions::InvalidFieldValue)

        expect do
          subject.validate_dependent_by_participant_id!(nil, valid_first_name, valid_last_name)
        end.to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end
  end
end
