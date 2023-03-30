# frozen_string_literal: true

require 'rails_helper'
require 'emis/payment_service_v2'

describe EMIS::PaymentServiceV2 do
  describe 'get_pay_grade_history' do
    let(:edipi) { '1007697216' }

    context 'with a valid request' do
      it 'calls the get_pay_grade_history endpoint with a proper emis message' do
        header_matcher = lambda do |r1, r2|
          [r1, r2].each { |r| r.headers.delete('Date') }
          expect(r1.headers).to eq(r2.headers)
        end

        allow(SecureRandom).to receive(:uuid).and_return('abc123')

        VCR.use_cassette('emis/get_pay_grade_history/success',
                         match_requests_on: [:method, :uri, header_matcher, :body]) do
          response = subject.get_pay_grade_history(edipi:)

          expect(response).to be_ok

          first_item = response.items.first
          expect(first_item.pay_plan_code).to eq('ME')
          expect(first_item.personnel_segment_identifier).to eq('1')
          expect(first_item.pay_plan_code).to eq('ME')
          expect(first_item.pay_grade_code).to eq('04')
          expect(first_item.service_rank_name_code).to eq('SRA')
          expect(first_item.service_rank_name_txt).to eq('Senior Airman')
          expect(first_item.pay_grade_date).to eq(Date.parse('2009-04-12'))
        end
      end
    end
  end
end
