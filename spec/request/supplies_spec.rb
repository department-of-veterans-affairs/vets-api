# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'MDOT Medical Devices & Supplies', type: :request do
  include SchemaMatchers

  let(:loa1_user) { FactoryBot.create(:user, :loa1, ssn: '111223333') }

  let(:user_details) do
    {
      first_name: 'Greg',
      last_name: 'Anderson',
      middle_name: 'A',
      birth_date: '1949-03-04',
      ssn: '000555555'
    }
  end

  let(:good_order) do
    {
      use_veteran_address: true,
      use_temporary_address: false,
      order: [
        {
          product_id: 1
        },
        {
          product_id: 4
        }
      ],
      additional_request: ''
    }.to_json
  end

  let(:loa3_user) { build(:user, :loa3, user_details) }

  describe 'GET /v0/mdot/supplies' do
    context 'with a loa1 user' do
      before { sign_in_as(loa1_user) }

      it 'returns a forbidden error' do
        get '/v0/mdot/supplies'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with an authenticated user' do
      before { sign_in_as(loa3_user) }

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

  describe 'POST /v0/mdot/supplies' do
    context 'with a loa1 user' do
      before { sign_in_as(loa1_user) }

      it 'returns a forbidden error' do
        post '/v0/mdot/supplies', params: good_order
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with an loa3 user' do
      before { sign_in_as(loa3_user) }

      context 'with an accepted response' do
        it 'returns an order_id and accepted status' do
          VCR.use_cassette('mdot/post_supplies_202') do
            post '/v0/mdot/supplies', params: good_order
            expect(response).to have_http_status(:accepted)
            expect(response).to match_response_schema('mdot_supplies')
          end
        end
      end

      context 'with a veteran not in the system' do
        it 'returns a 404' do
          VCR.use_cassette('mdot/post_supplies_404') do
            post '/v0/mdot/supplies', params: good_order
            expect(response).to have_http_status(:not_found)
            expect(response).to match_response_schema('errors')
          end
        end
      end

      context 'with a server error' do
        it 'returns a 502 and logs an error message' do
          VCR.use_cassette('mdot/post_supplies_502') do
            post '/v0/mdot/supplies', params: good_order
            expect(response).to have_http_status(:bad_gateway)
            expect(response).to match_response_schema('errors')
          end
        end
      end
    end
  end
end
