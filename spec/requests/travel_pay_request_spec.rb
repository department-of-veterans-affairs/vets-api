# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'travel_pay' do
  include SchemaMatchers

  let(:user) { build(:user, :loa3) }

  before do
    sign_in_as(user)
  end

  describe 'GET /v0/letters' do
    it 'returns a 200 travel pay claims response' do
      VCR.use_cassette('travel_pay/200_claims') do
        get '/travel_pay/claims'
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
