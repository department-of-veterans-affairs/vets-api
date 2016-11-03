# frozen_string_literal: true
require 'rails_helper'
require 'common/exceptions'

describe Decorators::MviUserDecorator do
  context 'given a valid user' do
    let(:user) { FactoryGirl.build(:user) }
    let(:mvi_user) { FactoryGirl.build(:mvi_user) }
    let(:find_candidate_response) do
      {
        birth_date: mvi_user.birth_date.strftime('%Y%m%d'),
        edipi: mvi_user.mvi[:edipi],
        vba_corp_id: mvi_user.mvi[:vba_corp_id],
        family_name: mvi_user.mvi[:family_name],
        gender: mvi_user.mvi[:gender],
        given_names: mvi_user.mvi[:given_names],
        icn: mvi_user.mvi[:icn],
        mhv_id: mvi_user.mvi[:mhv_id],
        ssn: mvi_user.mvi[:ssn],
        status: mvi_user.mvi[:status]
      }
    end

    context 'when all correlation ids have values' do
      before(:each) do
        allow_any_instance_of(MVI::Service).to receive(:find_candidate).and_return(find_candidate_response)
      end

      describe '#create' do
        it 'should fetch and add mvi data to the user' do
          mvi_user = Decorators::MviUserDecorator.new(user).create
          expected_user = FactoryGirl.build(:mvi_user)
          expect(mvi_user.attributes).to eq(expected_user.attributes)
        end
      end
      context 'when a MVI::HTTPError is raised' do
        it 'should log an error message' do
          allow_any_instance_of(MVI::Service).to receive(:find_candidate).and_raise(
            MVI::HTTPError.new('MVI HTTP call failed', 500)
          )
          expect(Rails.logger).to receive(:error).once.with(/MVI HTTP error code: 500 for user:/)
          user_result = Decorators::MviUserDecorator.new(user).create
          expect(user_result).to_not be_nil
          expect(user_result.attributes).to eq(user.attributes)
          expect(user_result.mvi).to be_nil
        end
      end
      context 'when a MVI::ServiceError is raised' do
        it 'should log an error message' do
          allow_any_instance_of(MVI::Service).to receive(:find_candidate).and_raise(MVI::InvalidRequestError)
          expect(Rails.logger).to receive(:error).once.with(/MVI service error: MVI::InvalidRequestError for user:/)
          user_result = Decorators::MviUserDecorator.new(user).create
          expect(user_result).to_not be_nil
          expect(user_result.attributes).to eq(user.attributes)
          expect(user_result.mvi).to be_nil
        end
      end
      context 'when MVI::RecordNotFound is raised' do
        it 'should log an error message and return the unmodified user' do
          response = instance_double('MVI::Responses::FindCandidateResponse')
          allow(response).to receive(:query).and_return('foo')
          allow(response).to receive(:original_response).and_return('foo')
          allow_any_instance_of(MVI::Service).to receive(:find_candidate).and_raise(
            MVI::RecordNotFound.new('not found', response)
          )
          expect(Rails.logger).to receive(:error).once.with(/MVI record not found for user:/)
          user_result = Decorators::MviUserDecorator.new(user).create
          expect(user_result).to_not be_nil
          expect(user_result.mvi).to eq(Decorators::MviUserDecorator::NOT_FOUND)
        end
      end
    end

    context 'when a correlation id is nil' do
      before(:each) do
        find_candidate_response[:edipi] = nil
        allow_any_instance_of(MVI::Service).to receive(:find_candidate).and_return(find_candidate_response)
      end

      describe '#create' do
        it 'should fetch and add mvi data to the user' do
          mvi_user = Decorators::MviUserDecorator.new(user).create
          expected_user = FactoryGirl.build(:mvi_user, edipi: nil)
          expected_user.mvi[:edipi] = nil
          expect(mvi_user.attributes).to eq(expected_user.attributes)
        end
      end
    end
  end

  around do |example|
    ClimateControl.modify MOCK_MVI_SERVICE: 'false' do
      example.run
    end
  end
end
