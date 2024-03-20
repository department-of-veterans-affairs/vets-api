# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelPay::ClaimsController, type: :request do
  let(:user) { build(:user) }

  describe '#index' do
    context 'successful response from API' do
      it 'responds with 200' do
        sign_in(user)
        get '/travel_pay/claims'
        expect(response).to have_http_status(:ok)
        expect_any_instance_of(TravelPay::Client).to receive(:get_claims)
      end
    end
  end
end
