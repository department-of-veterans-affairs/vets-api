# frozen_string_literal: true
require 'rails_helper'
require 'common/exceptions'

describe Decorators::MviUserDecorator do
  context 'given a valid user' do
    let(:user) { FactoryGirl.build(:user) }
    let(:test_mvi_user) { FactoryGirl.build(:mvi_user) }

    before(:each) do
      allow(MVI::Service).to receive(:find_candidate).and_return(test_mvi_user.mvi)
    end

    describe '#create' do
      it 'should fetch and add mvi data to the user' do
        mvi_user = Decorators::MviUserDecorator.new(user).create
        expected_user = FactoryGirl.build(:mvi_user, icn: test_mvi_user.mvi[:icn])
        expect(mvi_user.attributes).to eq(expected_user.attributes)
      end
    end
    context 'when a MVI::ServiceError is raised' do
      it 'should log an error message' do
        allow(MVI::Service).to receive(:find_candidate).and_raise(MVI::HTTPError)
        expect(Rails.logger).to receive(:error).once.with(/Error retrieving MVI data for user:/)
        expect { Decorators::MviUserDecorator.new(user).create }.to raise_error(Common::Exceptions::InternalServerError)
      end
    end
  end

  around do |example|
    ClimateControl.modify MOCK_MVI_SERVICE: 'false' do
      example.run
    end
  end
end
