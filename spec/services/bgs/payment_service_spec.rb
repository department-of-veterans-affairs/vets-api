# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::PaymentService do
  let(:user) { FactoryBot.create(:evss_user, :loa3) }
  let(:person) { BGS::People::Response.new(bgs_response) }
  let(:bgs_response) do
    {
      file_nbr: file_number,
      ssn_nbr: ssn_number,
      ptcpnt_id: participant_id
    }
  end
  let(:file_number) { '796043735' }
  let(:ssn_number) { '796043735' }
  let(:participant_id) { '600061742' }

  describe '#payment_history' do
    it 'returns a user\'s payment history given the user\'s participant id and file number' do
      VCR.use_cassette('bgs/payment_service/payment_history') do
        service = BGS::PaymentService.new(user)
        response = service.payment_history(person)

        expect(response).to include(:payments)
      end
    end

    context 'if there are no results for the user' do
      let(:file_number) { '000000000' }
      let(:participant_id) { '000000000' }

      it 'returns an empty result' do
        VCR.use_cassette('bgs/payment_service/no_payment_history') do
          response = BGS::PaymentService.new(user).payment_history(person)
          expect(response).to include({ payments: { payment: [] } })
        end
      end
    end

    context 'error' do
      let(:file_number) { '000000000' }
      let(:participant_id) { '000000000' }

      it 'logs an error' do
        response = BGS::PaymentService.new(user)
        expect_any_instance_of(BGS::PaymentInformationService)
          .to receive(:retrieve_payment_summary_with_bdn).and_raise(StandardError)
        expect(response).to receive(:log_exception_to_sentry)
        response.payment_history(person)
      end
    end
  end
end
