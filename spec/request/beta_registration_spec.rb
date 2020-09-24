# frozen_string_literal: true

require 'rails_helper'
require 'beta_switch' # required to use beta_enabled? method

RSpec.describe 'Beta Registration Endpoint', type: :request do
  let(:user) { build(:user, :loa3) }
  let(:dummy_class) { Class.new { extend BetaSwitch } }

  before do
    sign_in_as(user)
  end

  include BetaSwitch

  def assert_beta_enabled(feature, enabled)
    expect(beta_enabled?(user.uuid, feature)).to eq(enabled)
  end

  it 'returns 404 for unregistered user' do
    get '/v0/beta_registration/veteran_id_card'
    expect(response).to have_http_status(:not_found)
  end

  it 'accepts register request for emis_prefill' do
    assert_beta_enabled('emis_prefill', false)
    post '/v0/beta_registration/emis_prefill'
    assert_beta_enabled('emis_prefill', true)
  end

  it 'accepts register request' do
    post '/v0/beta_registration/veteran_id_card'
    expect(response).to be_successful
    expect(response.body).to be_a(String)
    json = JSON.parse(response.body)
    expect(json['user']).to eq(user.email)
  end

  it 'returns record if already registered' do
    post '/v0/beta_registration/veteran_id_card'
    get '/v0/beta_registration/veteran_id_card'
    expect(response).to be_successful
    json = JSON.parse(response.body)
    expect(json['user']).to eq(user.email)
  end

  it 'is reflected in beta_switch' do
    post '/v0/beta_registration/veteran_id_card'
    expect(dummy_class).to be_beta_enabled(user.uuid, 'veteran_id_card')
  end
end
