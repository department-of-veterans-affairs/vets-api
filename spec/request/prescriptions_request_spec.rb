# frozen_string_literal: true
require 'rails_helper'
require 'rx/client'
require 'support/rx_client_helpers'

RSpec.describe 'Prescriptions Integration', type: :request do
  include Rx::ClientHelpers
  before(:each) do
    allow_any_instance_of(ApplicationController).to receive(:authenticate).and_return(true)
    expect(Rx::Client).to receive(:new).once.and_return(authenticated_client)
  end

  it 'responds to GET #show' do
    VCR.use_cassette('prescriptions/1435525/index/no_parameters') do
      get '/v0/prescriptions/1435525'
      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('prescription')
    end
  end

  it 'responds to GET #index with no parameters' do
    VCR.use_cassette('prescriptions/1435525/index/no_parameters') do
      get '/v0/prescriptions'
      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('prescriptions')
      expect(JSON.parse(response.body)['meta']['sort']).to eq('ordered_date' => 'DESC')
    end
  end

  it 'responds to GET #index with refill_status=active' do
    VCR.use_cassette('prescriptions/1435525/index/refill_status_active') do
      get '/v0/prescriptions?refill_status=active'
      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('prescriptions')
      expect(JSON.parse(response.body)['meta']['sort']).to eq('ordered_date' => 'DESC')
    end
  end

  it 'responds to GET #index with filter' do
    VCR.use_cassette('prescriptions/1435525/index/refill_status_unknown') do
      get '/v0/prescriptions?filter[[refill_status][eq]]=unknown'
      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('prescriptions_filtered')
    end
  end

  it 'responds to POST #refill' do
    VCR.use_cassette('prescriptions/refill_action') do
      patch '/v0/prescriptions/1435525/refill'
      expect(response).to be_success
      expect(response.body).to be_empty
    end
  end

  context 'nested resources' do
    it 'responds to GET #show of nested tracking resource' do
      VCR.use_cassette('prescriptions/1435525/tracking') do
        get '/v0/prescriptions/1435525/trackings'
        expect(response).to be_success
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('trackings')
        expect(JSON.parse(response.body)['meta']['sort']).to eq('shipped_date' => 'DESC')
      end
    end
  end
end
