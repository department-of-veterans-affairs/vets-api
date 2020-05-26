# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Debts API Endpoint', type: :request do
  include SchemaMatchers

  before { sign_in_as(user) }

  describe 'GET /debts' do
    context 'with a veteran who has debts' do
      let(:user) { create(:user, :loa3, ssn: '000000009') }

      it 'returns a 200 with the array of debts' do
        VCR.use_cassette('debts/get_letters') do
          get '/v0/debts'
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('debts')
        end
      end
    end
  end
end
