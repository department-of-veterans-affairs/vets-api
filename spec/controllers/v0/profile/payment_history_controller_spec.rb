# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Profile::PaymentHistoryController, type: :controller do
  let(:user) { create(:evss_user) }

  describe '#index' do
    context 'with only regular payments' do
      it 'returns only payments and no return payments' do
        VCR.use_cassette('bgs/payment_history/retrieve_payment_summary_with_bdn') do
          sign_in_as(user)
          get(:index)

          expect(response.code).to eq('200')
          expect(response).to have_http_status(:ok)

          expect(JSON.parse(response.body)['data']['attributes']['payments'].count).to eq(47)
          expect(JSON.parse(response.body)['data']['attributes']['return_payments'].count).to eq(0)
        end
      end
    end

    context 'with mixed payments and return payments' do
      it 'returns both' do
        VCR.use_cassette('bgs/payment_history/retrieve_payment_summary_with_bdn_returns') do
          sign_in_as(user)
          get(:index)

          expect(response.code).to eq('200')
          expect(response).to have_http_status(:ok)

          expect(JSON.parse(response.body)['data']['attributes']['payments'].count).to eq(2)
          expect(JSON.parse(response.body)['data']['attributes']['return_payments'].count).to eq(2)
        end
      end
    end

    context 'with mixed payments and flipper disabled' do
      it 'does not return both' do
        Flipper.disable('payment_history')
        VCR.use_cassette('bgs/payment_history/retrieve_payment_summary_with_bdn_returns') do
          sign_in_as(user)
          get(:index)

          expect(response.code).to eq('200')
          expect(response).to have_http_status(:ok)

          expect(JSON.parse(response.body)['data']['attributes']['payments'].count).to eq(0)
          expect(JSON.parse(response.body)['data']['attributes']['return_payments'].count).to eq(0)
        end
        Flipper.enable('payment_history')
      end
    end
  end
end
