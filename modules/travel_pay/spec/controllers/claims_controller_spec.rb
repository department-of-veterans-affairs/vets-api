# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelPay::ClaimsController, type: :request do
  let(:user) { build(:user) }

  before do
    veis_response = double
    allow(veis_response).to receive(:body).and_return( {'access_token' => 'sample_token'} )
    allow_any_instance_of(TravelPay::Client).to receive(:request_veis_token).and_return(veis_response)
    btsss_ping_response = double
    allow(btsss_ping_response).to receive(:status).and_return('online')
    allow_any_instance_of(TravelPay::Client).to receive(:ping).and_return(btsss_ping_response)
    sign_in(user)
    Flipper.disable :travel_pay_power_switch
  end

  describe '#index' do
    context 'the feature switch is enabled' do
      before do
        Flipper.enable :travel_pay_power_switch
      end

      it 'requests a token and sends a ping to BTSSS' do
        get '/travel_pay/claims'
        expect(response.body).to include('Received ping from upstream server with status online.')
      end
    end

    context 'the feature switch is disabled' do
      it 'raises the proper error' do
        get '/travel_pay/claims'
        expect(response).to have_http_status(503)
        expect(response.body).to include('This feature has been temporarily disabled')
      end
    end
  end
end
