# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::PaymentService do
  let(:user) { create(:evss_user, :loa3) }
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

    context 'when :payment_history_exclude_third_party_disbursements is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).and_call_original
        allow(Flipper).to receive(:enabled?).with(:payment_history_exclude_third_party_disbursements).and_return(true)
      end

      it 'EXCLUDES payments sent to people other than the logged-in user' do
        VCR.use_cassette('bgs/payment_service/payment_history') do
          service = BGS::PaymentService.new(user)
          response = service.payment_history(person)
          beneficiary_ids = response[:payments][:payment].map { |pay| pay[:beneficiary_participant_id] }
          recipient_ids = response[:payments][:payment].map { |pay| pay[:recipient_participant_id] }
          expect(beneficiary_ids).to eq(recipient_ids)
          payee_types = response[:payments][:payment].map { |pay| pay[:payee_type] }
          expect(payee_types).not_to include('Third Party/Vendor')
        end
      end
    end

    context 'when :payment_history_exclude_third_party_disbursements is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).and_call_original
        allow(Flipper).to receive(:enabled?).with(:payment_history_exclude_third_party_disbursements).and_return(false)
      end

      it 'includes payments sent to people other than the logged-in user' do
        VCR.use_cassette('bgs/payment_service/payment_history') do
          service = BGS::PaymentService.new(user)
          response = service.payment_history(person)
          beneficiary_ids = response[:payments][:payment].map { |pay| pay[:beneficiary_participant_id] }
          recipient_ids = response[:payments][:payment].map { |pay| pay[:recipient_participant_id] }
          expect(beneficiary_ids).not_to eq(recipient_ids)
          payee_types = response[:payments][:payment].map { |pay| pay[:payee_type] }
          expect(payee_types).to include('Third Party/Vendor')
        end
      end
    end

    context 'when :payment_history_recategorize_hardship is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).and_call_original
        allow(Flipper).to receive(:enabled?).with(:payment_history_recategorize_hardship).and_return(true)
      end

      it 'prepends CH33 to the hardship payment type' do
        VCR.use_cassette('bgs/payment_service/payment_history') do
          service = BGS::PaymentService.new(user)
          response = service.payment_history(person)
          expect(response[:payments][:payment].last[:payment_type]).to eq('CH 33 Hardship (Manual) C&P')
        end
      end
    end

    context 'when :payment_history_recategorize_hardship is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).and_call_original
        allow(Flipper).to receive(:enabled?).with(:payment_history_recategorize_hardship).and_return(false)
      end

      it 'does not prepend CH33 to the hardship payment type' do
        VCR.use_cassette('bgs/payment_service/payment_history') do
          service = BGS::PaymentService.new(user)
          response = service.payment_history(person)
          expect(response[:payments][:payment].last[:payment_type]).to eq('Hardship (Manual) C&P')
        end
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
