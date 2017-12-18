# frozen_string_literal: true
require 'rails_helper'
require 'rx/client'
require 'support/rx_client_helpers'

RSpec.describe 'prescriptions', type: :request do
  include Rx::ClientHelpers
  include SchemaMatchers

  let(:mhv_account) { double('mhv_account', eligible?: true, needs_terms_acceptance?: false, accessible?: true) }
  let(:current_user) { build(:user, :mhv) }

  before(:each) do
    allow(MhvAccount).to receive(:find_or_initialize_by).and_return(mhv_account)
    allow(Rx::Client).to receive(:new).and_return(authenticated_client)
    use_authenticated_current_user(current_user: current_user)
  end

  context 'forbidden user' do
    let(:mhv_account) { double('mhv_account', eligible?: false, needs_terms_acceptance?: false, accessible?: false) }
    let(:current_user) { build(:user) }

    it 'raises access denied' do
      get '/v0/prescriptions/13651310'

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['errors'].first['detail'])
        .to eq('You do not have access to prescriptions')
    end
  end

  context 'terms of service not accepted' do
    let(:mhv_account) { double('mhv_account', eligible?: true, needs_terms_acceptance?: true, accessible?: false) }
    let(:current_user) { build(:user, :loa3) }

    it 'raises access denied' do
      get '/v0/prescriptions/13651310'
      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['errors'].first['detail'])
        .to eq('You have not accepted the terms of service')
    end
  end

  context 'mhv account not upgraded' do
    let(:mhv_account) { double('mhv_account', eligible?: true, needs_terms_acceptance?: false, accessible?: false) }
    let(:current_user) { build(:user, :loa3) }

    before(:each) do
      allow_any_instance_of(MhvAccount).to receive(:create_and_upgrade!)
    end

    it 'raises forbidden' do
      get '/v0/prescriptions/13651310'
      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['errors'].first['detail'])
        .to eq('Failed to create or upgrade health tools account access')
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

    it 'responds to GET #show of nested tracking resource with a shipment having no other prescriptions' do
      VCR.use_cassette('rx_client/prescriptions/nested_resources/gets_tracking_with_empty_other_prescriptions') do
        get '/v0/prescriptions/13650541/trackings'
      end

      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('trackings')
      expect(JSON.parse(response.body)['meta']['sort']).to eq('shipped_date' => 'DESC')
    end
  end

  context 'preferences' do
    it 'responds to GET #show of preferences' do
      VCR.use_cassette('rx_client/preferences/gets_rx_preferences') do
        get '/v0/prescriptions/preferences'
      end

      expect(response).to be_success
      expect(response.body).to be_a(String)
      attrs = JSON.parse(response.body)['data']['attributes']
      expect(attrs['email_address']).to eq('Praneeth.Gaganapally@va.gov')
      expect(attrs['rx_flag']).to be true
    end

    it 'responds to PUT #update of preferences' do
      VCR.use_cassette('rx_client/preferences/sets_rx_preferences', record: :none) do
        params = { email_address: 'kamyar.karshenas@va.gov',
                   rx_flag: false }
        put '/v0/prescriptions/preferences', params
      end

      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body)['data']['id'])
        .to eq('59623c5f11b874409315b05a254a7ace5f6a1b12a21334f7b3ceebe1f1854948')
      expect(JSON.parse(response.body)['data']['attributes'])
        .to eq('email_address' => 'kamyar.karshenas@va.gov', 'rx_flag' => false)
    end

    it 'requires all parameters for update' do
      VCR.use_cassette('rx_client/preferences/sets_rx_preferences', record: :none) do
        params = { email_address: 'kamyar.karshenas@va.gov' }
        put '/v0/prescriptions/preferences', params
      end

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns a custom exception mapped from i18n when email contains spaces' do
      VCR.use_cassette('rx_client/preferences/raises_a_backend_service_exception_when_email_includes_spaces') do
        params = { email_address: 'kamyar karshenas@va.gov',
                   rx_flag: false }
        put '/v0/prescriptions/preferences', params
      end

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['errors'].first['code']).to eq('RX157')
    end
  end
end
