# frozen_string_literal: true
require 'rails_helper'
require 'mvi/responses/find_candidate'
require "#{Rails.root}/spec/support/mvi/mvi_response"

describe MVI::Responses::FindCandidate do
  context 'given a valid savon response' do
    let(:valid_response) { MVI::Responses::FindCandidate.new(mvi_valid_response) }

    describe '#invalid?' do
      it 'should return false' do
        expect(valid_response.invalid?).to be_falsey
      end
    end

    describe '#failure?' do
      it 'should return false' do
        expect(valid_response.failure?).to be_falsey
      end
    end

    describe '.body' do
      context 'with middle name and icn, mhv correlation ids' do
        it 'should filter the patient attributes the system is interested in' do
          expect(valid_response.body).to eq(
            birth_date: '19800101',
            edipi: '1234^NI^200DOD^USDOD^A',
            vba_corp_id: '12345678^PI^200CORP^USVBA^A',
            family_name: 'Smith',
            gender: 'M',
            given_names: %w(John William),
            icn: '1000123456V123456^NI^200M^USVHA^P',
            mhv_id: '123456^PI^200MHV^USVHA^A',
            ssn: '555443333',
            status: 'active'
          )
        end
      end
    end
  end

  context 'with no middle name, missing correlation ids, multiple other_ids' do
    let(:valid_response_missing_attrs) { MVI::Responses::FindCandidate.new(mvi_valid_response_missing_attrs) }

    describe '.to_h' do
      it 'should filter with only first name' do
        expect(valid_response_missing_attrs.body).to eq(
          birth_date: '19320205',
          edipi: nil,
          mhv_id: nil,
          vba_corp_id: nil,
          family_name: 'Allen',
          gender: 'M',
          given_names: %w(Hector),
          icn: '1008704012V552302^NI^200M^USVHA^P',
          ssn: '111223333',
          status: 'active'
        )
      end
    end
  end

  context 'given an invalid response' do
    let(:invalid_response) { MVI::Responses::FindCandidate.new(mvi_savon_invalid_response) }

    describe '#invalid?' do
      it 'should return false' do
        expect(invalid_response.invalid?).to be_truthy
      end
    end

    describe '#failure?' do
      it 'should return false' do
        expect(invalid_response.failure?).to be_falsey
      end
    end
  end

  context 'given a failure response' do
    let(:failure_response) { MVI::Responses::FindCandidate.new(mvi_savon_failure_response) }

    describe '#invalid?' do
      it 'should return false' do
        expect(failure_response.invalid?).to be_falsey
      end
    end

    describe '#failure?' do
      it 'should return false' do
        expect(failure_response.failure?).to be_truthy
      end
    end
  end
end
