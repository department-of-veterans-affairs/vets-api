# frozen_string_literal: true
require 'rails_helper'
require 'mvi/response'
require "#{Rails.root}/spec/support/mvi/mvi_savon_response"

describe MVI::Response do
  context 'given a valid savon response' do
    let(:valid_response) { MVI::Response.new(mvi_savon_valid_response) }

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

    describe '.to_h' do
      it 'should filter the patient attributes the system is interested in' do
        expect(valid_response.to_h).to eq(
          birth_date: '19800101',
          edipi: '1234^NI^200DOD^USDOD^A',
          family_name: 'Smith',
          gender: 'M',
          given_names: %w(John William),
          icn: '1000123456V123456^NI^200M^USVHA^P',
          mhv: '123456^PI^200MHV^USVHA^A',
          ssn: '555-44-3333',
          status: 'active'
        )
      end
    end
  end
  context 'given an invalid response' do
    let(:invalid_response) { MVI::Response.new(mvi_savon_invalid_response) }

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
    let(:failure_response) { MVI::Response.new(mvi_savon_failure_response) }

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
