# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelPay::ClaimsController, type: :controller do
  before do
    veis_response = double
    allow(veis_response).to receive(:body).and_return( {'access_token' => 'sample_token'} )
    allow_any_instance_of(TravelPay::Client).to receive(:request_veis_token).and_return(veis_response)
    btsss_ping_response = double
    allow(btsss_ping_response).to receive(:status).and_return('online')
    allow_any_instance_of(TravelPay::Client).to receive(:ping).and_return(btsss_ping_response)
  end

  describe '#index' do
    it 'requests a token and sends a ping to BTSSS' do
      get(:index)
      expect(response.body).to eq('Received ping from upstream server with status online.')
    end
  end
end
