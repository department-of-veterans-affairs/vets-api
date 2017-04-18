# frozen_string_literal: true
require 'rails_helper'
require 'emis/payment_service'

describe EMIS::PaymentService do
  let(:edipi) { '1607472595' }

  describe 'get_combat_pay' do
    context 'with a valid request' do
      it 'calls the get_combat_pay endpoint with a proper emis message' do
        VCR.use_cassette('emis/get_combat_pay/valid') do
          response = subject.get_combat_pay(edipi: edipi)
          expect(response).to be_ok
        end
      end
    end
  end

  describe 'get_reserve_drill_days' do
    context 'with a valid request' do
      it 'calls the get_reserve_drill_days endpoint with a proper emis message' do
        VCR.use_cassette('emis/get_reserve_drill_days/valid') do
          response = subject.get_reserve_drill_days(edipi: edipi)
          expect(response).to be_ok
        end
      end
    end
  end

  describe 'get_retirement' do
    context 'with a valid request' do
      it 'calls the get_retirement endpoint with a proper emis message' do
        VCR.use_cassette('emis/get_retirement/valid') do
          response = subject.get_retirement(edipi: edipi)
          expect(response).to be_ok
        end
      end
    end
  end

  describe 'get_separation_pay' do
    context 'with a valid request' do
      it 'calls the get_separation_pay endpoint with a proper emis message' do
        VCR.use_cassette('emis/get_separation_pay/valid') do
          response = subject.get_separation_pay(edipi: edipi)
          expect(response).to be_ok
        end
      end
    end
  end
end
