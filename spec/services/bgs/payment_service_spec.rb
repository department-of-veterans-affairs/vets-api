# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::PaymentService do
  let(:user) { FactoryBot.create(:evss_user, :loa3) }

  describe '#payment_history' do
    it 'returns a user\'s payment history given the user\'s ssn' do
      VCR.use_cassette('bgs/payment_service/payment_history') do
        service = BGS::PaymentService.new(user)
        response = service.payment_history

        expect(response).to include(:file_number, :payment_address, :payments, :return_payments, :full_name)
      end
    end

    it 'returns an empty result if there are no results for the user' do
      VCR.use_cassette('bgs/payment_service/no_payment_history') do
        expect(user).to receive(:ssn).and_return('000000000')

        response = BGS::PaymentService.new(user).payment_history
        expect(response).to include({ payment_address: [], payments: [], return_payments: [] })
      end
    end

    context 'error' do
      it 'logs an error' do
        response = BGS::PaymentService.new(user)

        expect_any_instance_of(BGS::PaymentHistoryWebService).to receive(:find_by_ssn).and_raise(StandardError)
        expect(response).to receive(:log_exception_to_sentry)

        response.payment_history
      end
    end
  end
end
