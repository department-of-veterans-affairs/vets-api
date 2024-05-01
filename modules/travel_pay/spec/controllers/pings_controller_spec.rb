# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelPay::PingsController, type: :request do
  let(:user) { build(:user) }
  let(:client) { instance_double(TravelPay::Client) }

  before do
    allow(TravelPay::Client).to receive(:new).and_return(client)
    allow(client).to receive(:request_veis_token).and_return('sample_token')
    btsss_ping_response = double
    allow(btsss_ping_response).to receive(:status).and_return(200)

    allow(client)
      .to receive(:ping)
      .with('sample_token')
      .and_return(btsss_ping_response)

    sign_in(user)

    Flipper.disable :travel_pay_power_switch
  end

  describe '#ping' do
    context 'the feature switch is enabled' do
      before do
        Flipper.enable :travel_pay_power_switch
      end

      it 'requests a token and sends a ping to BTSSS' do
        expect(client).to receive(:ping)
        get '/travel_pay/pings/ping'
        expect(response.body).to include('ping')
      end
    end

    context 'the feature switch is disabled' do
      it 'raises the proper error' do
        get '/travel_pay/pings/ping'
        expect(response).to have_http_status(:not_found)
        expect(response.body).to include('This feature has been temporarily disabled')
      end
    end
  end

  describe '#authorized_ping' do
    before do
      btsss_authorized_ping_response = double
      allow(btsss_authorized_ping_response).to receive(:status).and_return(200)
      allow(client)
        .to receive(:request_sts_token)
        .and_return('sample_sts_token')
      allow(client)
        .to receive(:request_btsss_token)
        .and_return('sample_btsss_token')
      allow(client)
        .to receive(:authorized_ping)
        .with('sample_token', 'sample_btsss_token')
        .and_return(btsss_authorized_ping_response)
    end

    context 'the feature switch is enabled' do
      before do
        Flipper.enable :travel_pay_power_switch
      end

      it 'requests a token and sends a ping to BTSSS' do
        expect(client).to receive(:authorized_ping)
        get '/travel_pay/pings/authorized_ping', headers: { 'Authorization' => 'Bearer vagov_token' }
        expect(response.body).to include('authorized ping')
      end
    end

    context 'the feature switch is disabled' do
      it 'raises the proper error' do
        get '/travel_pay/pings/authorized_ping', headers: { 'Authorization' => 'Bearer vagov_token' }
        expect(response).to have_http_status(:not_found)
        expect(response.body).to include('This feature has been temporarily disabled')
      end
    end
  end
end
