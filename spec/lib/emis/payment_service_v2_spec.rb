# frozen_string_literal: true

require 'rails_helper'
require 'emis/payment_service'

describe EMIS::PaymentServiceV2 do
  describe 'get_pay_grade_history' do
    let(:edipi) { '1007697216' }

    context 'with a valid request' do
      it 'calls the get_pay_grade_history endpoint with a proper emis message' do
        VCR.use_cassette('emis/get_pay_grade_history/success') do
          response = subject.get_pay_grade_history(edipi: edipi)
          expect(response).to be_ok
        end
      end
    end
  end
end
