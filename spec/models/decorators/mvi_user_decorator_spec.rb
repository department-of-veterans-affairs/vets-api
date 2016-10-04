# frozen_string_literal: true
require 'rails_helper'
require 'common/exceptions'

describe Decorators::MviUserDecorator do
  context 'given a valid user' do
    let(:user) { FactoryGirl.build(:user) }

    before(:each) do
      allow(MVI::Service).to receive(:find_candidate).and_return(
        edipi: '1234^NI^200DOD^USDOD^A',
        icn: '1000123456V123456^NI^200M^USVHA^P',
        mhv: '123456^PI^200MHV^USVHA^A',
        status: 'active',
        given_names: %w(abraham),
        family_name: 'lincoln',
        gender: 'M',
        birth_date: '19800101',
        ssn: '272111863'
      )
    end

    describe '#create' do
      it 'should fetch and add mvi data to the user' do
        mvi_user = Decorators::MviUserDecorator.new(user).create
        expect(mvi_user.attributes).to eq(
          birth_date: user.birth_date,
          edipi: user.edipi,
          email: user.email,
          first_name: user.first_name,
          gender: user.gender,
          last_name: 'lincoln',
          last_signed_in: user.last_signed_in,
          middle_name: nil,
          level_of_assurance: 'http://idmanagement.gov/ns/assurance/loa/2',
          mvi: {
            edipi: '1234^NI^200DOD^USDOD^A',
            icn: '1000123456V123456^NI^200M^USVHA^P',
            mhv: '123456^PI^200MHV^USVHA^A',
            status: 'active',
            given_names: %w(abraham),
            family_name: 'lincoln',
            gender: 'M',
            birth_date: '19800101',
            ssn: '272111863'
          },
          participant_id: user.participant_id,
          ssn: '272111863',
          uuid: user.uuid,
          zip: '17325'
        )
      end
    end
    context 'when a MVI::ServiceError is raised' do
      it 'should log an error message' do
        allow(MVI::Service).to receive(:find_candidate).and_raise(MVI::HTTPError)
        expect { Decorators::MviUserDecorator.new(user).create }.to raise_error(Common::Exceptions::RecordNotFound)
      end
    end
  end
end
