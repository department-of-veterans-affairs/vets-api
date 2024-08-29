# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelPay::Pings, type: :request do
  let(:user) { build(:user) }

  before do
    sign_in(user)
    Flipper.disable :travel_pay_power_switch
  end

  describe '#ping' do
    context 'the feature switch is enabled' do
      before do
        Flipper.enable :travel_pay_power_switch
      end

      it 'requests a token and sends a ping to BTSSS' do
        VCR.use_cassette('travel_pay/ping') do
          get '/travel_pay/pings/ping'
          expect(response.body).to include('Received ping from upstream server with status 200')
        end
      end
    end

    context 'the feature switch is disabled' do
      it 'raises the proper error' do
        get '/travel_pay/pings/ping'
        expect(response).to have_http_status(:forbidden)
        expect(response.body).to include('You do not have access to travel pay')
      end
    end
  end

  describe '#authorized_ping' do
    context 'the feature switch is enabled' do
      before do
        Flipper.enable :travel_pay_power_switch
      end

      it 'requests a token and sends a ping to BTSSS' do
        VCR.use_cassette('travel_pay/auth_ping', match_requests_on: %i[method path]) do
          get '/travel_pay/pings/authorized_ping', headers: { 'Authorization' => 'Bearer vagov_token' }
          expect(response.body).to include('Received authorized ping from upstream server with status 200')
        end
      end
    end

    context 'the feature switch is disabled' do
      it 'raises the proper error' do
        get '/travel_pay/pings/authorized_ping', headers: { 'Authorization' => 'Bearer vagov_token' }
        expect(response).to have_http_status(:forbidden)
        expect(response.body).to include('You do not have access to travel pay')
      end
    end
  end
end
