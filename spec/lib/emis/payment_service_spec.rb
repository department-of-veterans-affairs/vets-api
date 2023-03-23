# frozen_string_literal: true

require 'rails_helper'
require 'emis/payment_service'

describe EMIS::PaymentService do
  describe 'get_combat_pay' do
    let(:edipi) { '1607472595' }

    context 'with a valid request' do
      it 'calls the get_combat_pay endpoint with a proper emis message' do
        VCR.use_cassette('emis/get_combat_pay/valid') do
          response = subject.get_combat_pay(edipi:)
          expect(response).to be_ok
        end
      end
    end
  end

  describe 'get_reserve_drill_days' do
    let(:edipi) { '6001010003' }

    context 'with a valid request' do
      it 'calls the get_reserve_drill_days endpoint with a proper emis message' do
        VCR.use_cassette('emis/get_reserve_drill_days/valid') do
          response = subject.get_reserve_drill_days(edipi:)
          expect(response).to be_ok
        end
      end
    end
  end

  describe 'get_retirement_pay' do
    let(:edipi) { '1607472595' }

    context 'with a valid request' do
      it 'calls the get_retirement_pay endpoint with a proper emis message' do
        VCR.use_cassette('emis/get_retirement_pay/valid') do
          response = subject.get_retirement_pay(edipi:)
          expect(response).to be_ok
        end
      end
    end
  end

  describe 'get_separation_pay' do
    let(:edipi) { '6001010001' }

    context 'with a valid request' do
      it 'calls the get_separation_pay endpoint with a proper emis message' do
        VCR.use_cassette('emis/get_separation_pay/valid') do
          response = subject.get_separation_pay(edipi:)
          expect(response).to be_ok
        end
      end
    end
  end
end
