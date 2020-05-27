# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Debts API Endpoint', type: :request do
  include SchemaMatchers

  describe 'GET /debts' do
    context 'with a veteran who has debts' do
      let(:user_with_ssn) { create(:user, :loa3, ssn: '000000009') }
      sign_in_as(user_with_ssn)

      it 'returns a 200 with the array of debts' do
        VCR.use_cassette('debts/get_letters') do
          get '/v0/debts'
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('debts')
        end
      end
    end
  end

  context 'with a veteran with empty ssn' do
    let(:user_without_ssn) { create(:user, :loa3, ssn: '')}
    sign_in_as(user_without_ssn)

    it 'returns an error' do
      VCR.use_cassette('debts/get_letters_error', :record => :all) do
        get '/v0/debts'
        expect(response).to have_http_status(:error)
      end
    end
  end
end
