# frozen_string_literal: true
require 'rails_helper'
require 'rx/client'
require 'support/rx_client_helpers'

RSpec.describe 'prescriptions', type: :request do
  include Rx::ClientHelpers

  let(:current_user) { build(:mhv_user) }

  before(:each) do
    allow(Rx::Client).to receive(:new).and_return(authenticated_client)
    use_authenticated_current_user(current_user: current_user)
  end

  context 'forbidden user' do
    let(:current_user) { build(:user) }

    it 'raises access denied' do
      get '/v0/prescriptions/13651310'

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['errors'].first['detail'])
        .to eq('You do not have access to prescriptions')
    end
  end

  it 'responds to GET #show' do
    VCR.use_cassette('rx_client/prescriptions/gets_a_single_prescription') do
      get '/v0/prescriptions/13651310'
    end

    expect(response).to be_success
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('prescription')
  end

  it 'responds to GET #index with no parameters' do
    VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions') do
      get '/v0/prescriptions'
    end

    expect(response).to be_success
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('prescriptions')
    expect(JSON.parse(response.body)['meta']['sort']).to eq('prescription_name' => 'ASC')
  end

  it 'responds to GET #index with refill_status=active' do
    VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_active_prescriptions') do
      get '/v0/prescriptions?refill_status=active'
    end

    expect(response).to be_success
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('prescriptions')
    expect(JSON.parse(response.body)['meta']['sort']).to eq('prescription_name' => 'ASC')
  end

  it 'responds to GET #index with filter' do
    VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions') do
      get '/v0/prescriptions?filter[[refill_status][eq]]=refillinprocess'
    end

    expect(response).to be_success
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('prescriptions_filtered')
  end

  it 'responds to POST #refill' do
    VCR.use_cassette('rx_client/prescriptions/refills_a_prescription') do
      patch '/v0/prescriptions/13650545/refill'
    end

    expect(response).to be_success
    expect(response.body).to be_empty
  end

  context 'nested resources' do
    it 'responds to GET #show of nested tracking resource' do
      VCR.use_cassette('rx_client/prescriptions/nested_resources/gets_a_list_of_tracking_history_for_a_prescription') do
        get '/v0/prescriptions/13650541/trackings'
      end

      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('trackings')
      expect(JSON.parse(response.body)['meta']['sort']).to eq('shipped_date' => 'DESC')
    end
  end
end
