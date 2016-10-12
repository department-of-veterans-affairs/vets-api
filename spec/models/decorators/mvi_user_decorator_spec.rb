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
        mhv_id: '123456^PI^200MHV^USVHA^A',
        vba_corp_id: '12345678^PI^200CORP^USVBA^A',
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
          icn: user.icn,
          edipi: user.edipi,
          mhv_id: user.mhv_id,
          email: user.email,
          first_name: user.first_name,
          gender: user.gender,
          last_name: 'lincoln',
          last_signed_in: user.last_signed_in,
          middle_name: nil,
          loa_current: LOA::TWO,
          loa_highest: LOA::THREE,
          mvi: {
            edipi: '1234^NI^200DOD^USDOD^A',
            icn: '1000123456V123456^NI^200M^USVHA^P',
            mhv_id: '123456^PI^200MHV^USVHA^A',
            vba_corp_id: '12345678^PI^200CORP^USVBA^A',
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
