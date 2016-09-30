# frozen_string_literal: true
require 'rails_helper'
require 'common/exceptions'

describe UserMviDelegate do
  context 'given a valid user' do
    let(:user) { FactoryGirl.build(:user) }

    before(:each) do
      allow(MVI::Service).to receive(:find_candidate).and_return(
        edipi: '1234^NI^200DOD^USDOD^A',
        icn: '1000123456V123456^NI^200M^USVHA^P',
        mhv: '123456^PI^200MHV^USVHA^A',
        status: 'active',
        given_names: %w(John William),
        family_name: 'Smith',
        gender: 'M',
        dob: '19800101',
        ssn: '555-44-3333'
      )
    end

    describe '#create' do
      it 'should fetch and add mvi data to the user' do
        mvi_user = UserMviDelegate.new(user).create
        expect(mvi_user.attributes).to eq(
          dob: user.dob,
          edipi: user.edipi,
          email: user.email,
          first_name: user.first_name,
          gender: user.gender,
          last_name: 'Smith',
          last_signed_in: user.last_signed_in,
          middle_name: 'William',
          mvi: {
            edipi: '1234^NI^200DOD^USDOD^A',
            icn: '1000123456V123456^NI^200M^USVHA^P',
            mhv: '123456^PI^200MHV^USVHA^A',
            status: 'active',
            given_names: %w(John William),
            family_name: 'Smith',
            gender: 'M',
            dob: '19800101',
            ssn: '555-44-3333'
          },
          participant_id: user.participant_id,
          ssn: '555-44-3333',
          uuid: user.uuid,
          zip: '90210'
        )
      end
    end
    context 'when a MVI::ServiceError is raised' do
      it 'should log an error message' do
        allow(MVI::Service).to receive(:find_candidate).and_raise(MVI::HTTPError)
        expect { UserMviDelegate.new(user).create }.to raise_error(Common::Exceptions::RecordNotFound)
      end
    end
  end
  context 'with an invalid user' do
    let(:user) { FactoryGirl.build(:user, ssn: nil) }
    it 'should log a warn message' do
      expect { UserMviDelegate.new(user).create }.to raise_error(Common::Exceptions::ValidationErrors)
    end
  end
end
