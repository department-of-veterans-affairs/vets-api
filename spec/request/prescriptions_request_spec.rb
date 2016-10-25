# frozen_string_literal: true
require 'rails_helper'
require 'rx/client'
require 'support/rx_client_helpers'

RSpec.describe 'prescriptions', type: :request do
  before(:each) do
    use_authenticated_current_user(klass: V0::PrescriptionsController, current_user: build(:prescription_user))
  end

  it 'responds to GET #show', :vcr do
    get '/v0/prescriptions/13651310'

    expect(response).to be_success
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('prescription')
  end

  it 'responds to GET #index with no parameters', :vcr do
    get '/v0/prescriptions'
    expect(response).to be_success
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('prescriptions')
    expect(JSON.parse(response.body)['meta']['sort']).to eq('ordered_date' => 'DESC')
  end

  it 'responds to GET #index with refill_status=active', :vcr do
    get '/v0/prescriptions?refill_status=active'
    expect(response).to be_success
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('prescriptions')
    expect(JSON.parse(response.body)['meta']['sort']).to eq('ordered_date' => 'DESC')
  end

  it 'responds to GET #index with filter', :vcr do
    get '/v0/prescriptions?filter[[refill_status][eq]]=refillinprocess'
    expect(response).to be_success
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('prescriptions_filtered')
  end

  it 'responds to POST #refill', :vcr do
    patch '/v0/prescriptions/13568747/refill'
    expect(response).to be_success
    expect(response.body).to be_empty
  end

  context 'nested resources', :vcr do
    it 'responds to GET #show of nested tracking resource', :vcr do
      get '/v0/prescriptions/13651310/trackings'
      expect(response).to be_success
      expect(response.body).to be_a(String)
      # Currently there are no prescriptions having trackings available
      # expect(response).to match_response_schema('trackings')
      # expect(JSON.parse(response.body)['meta']['sort']).to eq('shipped_date' => 'DESC')
    end
  end
end
