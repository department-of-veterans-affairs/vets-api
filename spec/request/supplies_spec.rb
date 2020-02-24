# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'MDOT Medical Devices & Supplies', type: :request do
  include SchemaMatchers

  context 'with a loa1 user' do
    let(:user) { FactoryBot.create(:user, :loa1, ssn: '111223333') }

    before { sign_in_as(user) }

    it 'returns a forbidden error' do
      get '/v0/mdot/supplies'
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'with an authenticated user' do
    let(:user_details) do
      {
        first_name: 'Greg',
        last_name: 'Anderson',
        middle_name: 'A',
        birth_date: '1949-03-04',
        ssn: '000555555'
      }
    end

    let(:user) { build(:user, :loa3, user_details) }

    before { sign_in_as(user) }

    context 'with a valid response' do
      it 'lists medical devices and supplies for the veteran' do
        VCR.use_cassette('mdot/get_supplies_200') do
          get '/v0/mdot/supplies'
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('mdot_supplies')
        end
      end
    end

    context 'with a veteran not in DLC system' do
      it 'returns a 404 not found' do
        VCR.use_cassette('mdot/get_supplies_404') do
          get '/v0/mdot/supplies'
          expect(response).to have_http_status(:not_found)
          expect(response).to match_response_schema('errors')
        end
      end
    end

    context 'with a server error' do
      it 'returns a 502 and logs an error message' do
        VCR.use_cassette('mdot/get_supplies_502') do
          get '/v0/mdot/supplies'
          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('errors')
        end
      end
    end
  end
end
