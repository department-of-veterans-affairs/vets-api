# frozen_string_literal: true
require 'rails_helper'
require 'rx/client'

RSpec.describe 'prescriptions', type: :request do
  let(:current_user) { build(:prescription_user) }
  # before(:each)      { use_authenticated_current_user(current_user: current_user) }

  context 'forbidden user' do
    let(:current_user) { build(:user) }

    xit 'raises access denied', :vcr do
      get '/v0/prescriptions/13651310'

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['errors'].first['detail'])
        .to eq('You do not have access to prescriptions')
    end
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
    expect(JSON.parse(response.body)['meta']['sort']).to eq('refill_submit_date' => 'DESC')
  end

  it 'responds to GET #index with refill_status=active', :vcr do
    get '/v0/prescriptions?refill_status=active'
    expect(response).to be_success
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('prescriptions')
    expect(JSON.parse(response.body)['meta']['sort']).to eq('refill_submit_date' => 'DESC')
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
      get '/v0/prescriptions/13650541/trackings'
      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('trackings')
      expect(JSON.parse(response.body)['meta']['sort']).to eq('shipped_date' => 'DESC')
    end
  end
end
