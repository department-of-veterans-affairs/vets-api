# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Profile::PaymentHistoryController, type: :controller do
  let(:user) { create(:evss_user) }

  describe '#index' do
    context 'with a valid bgs response' do
      it 'returns true if a logged-in user has a valid va file number' do
        VCR.use_cassette('bgs/payment_history/find_by_ssn') do
          sign_in_as(user)
          get(:index)

          expect(response.code).to eq('200')
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['data']['attributes']['payments'].count).to be > 2
          expect(JSON.parse(response.body)['data']['attributes']['return_payments'].count).to be > 2
        end
      end
    end
  end
end
