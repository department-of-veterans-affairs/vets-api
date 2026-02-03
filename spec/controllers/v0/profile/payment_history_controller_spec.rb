# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Profile::PaymentHistoryController, type: :controller do
  let(:user) { create(:evss_user) }

  describe '#index' do
    context 'with only regular payments' do
      it 'returns only payments and no return payments' do
        allow(Flipper).to receive(:enabled?).with(:payment_history_detailed_logging).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:payment_history_exception_logging).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:payment_history_validation_logging).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:payment_history).and_return(true)

        VCR.use_cassette('bgs/person_web_service/find_person_by_participant_id') do
          VCR.use_cassette('bgs/payment_history/retrieve_payment_summary_with_bdn') do
            sign_in_as(user)
            get(:index)

            response_body = JSON.parse(response.body)
            payments_count = response_body.dig('data', 'attributes', 'payments')&.count
            return_payments_count = response_body.dig('data', 'attributes', 'return_payments')&.count

            expect(response).to have_http_status(:ok)

            expect(payments_count).to eq(47)
            expect(return_payments_count).to eq(0)
          end
        end
      end
    end

    context 'with mixed payments and return payments' do
      it 'returns both' do
        allow(Flipper).to receive(:enabled?).with(:payment_history_detailed_logging).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:payment_history_exception_logging).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:payment_history_validation_logging).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:payment_history).and_return(true)

        VCR.use_cassette('bgs/person_web_service/find_person_by_participant_id') do
          VCR.use_cassette('bgs/payment_history/retrieve_payment_summary_with_bdn_returns') do
            sign_in_as(user)
            get(:index)

            response_body = JSON.parse(response.body)
            payments_count = response_body.dig('data', 'attributes', 'payments')&.count
            return_payments_count = response_body.dig('data', 'attributes', 'return_payments')&.count

            expect(response).to have_http_status(:ok)

            expect(payments_count).to eq(2)
            expect(return_payments_count).to eq(2)
          end
        end
      end
    end

    context 'with mixed payments and flipper disabled' do
      it 'does not return both' do
        allow(Flipper).to receive(:enabled?).with(:payment_history_detailed_logging).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:payment_history_exception_logging).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:payment_history_validation_logging).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:payment_history).and_return(false)

        VCR.use_cassette('bgs/person_web_service/find_person_by_participant_id') do
          VCR.use_cassette('bgs/payment_history/retrieve_payment_summary_with_bdn_returns') do
            sign_in_as(user)
            get(:index)

            response_body = JSON.parse(response.body)
            payments_count = response_body.dig('data', 'attributes', 'payments')&.count
            return_payments_count = response_body.dig('data', 'attributes', 'return_payments')&.count

            expect(response).to have_http_status(:ok)

            expect(payments_count).to eq(0)
            expect(return_payments_count).to eq(0)
          end
        end
      end
    end
  end
end
