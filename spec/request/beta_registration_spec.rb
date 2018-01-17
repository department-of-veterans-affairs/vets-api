# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Beta Registration Endpoint', type: :request do
  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:user) { build(:user, :loa3) }

  let(:dummy_class) { Class.new { extend BetaSwitch } }

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
  end

  include BetaSwitch

  def assert_beta_enabled(feature, enabled)
    expect(beta_enabled?(user.uuid, feature)).to eq(enabled)
  end

  it 'returns 404 for unregistered user' do
    get '/v0/beta_registration/veteran_id_card', nil, auth_header
    expect(response).to have_http_status(:not_found)
  end

  it 'accepts register request for emis_prefill' do
    assert_beta_enabled('emis_prefill', false)
    post '/v0/beta_registration/emis_prefill', nil, auth_header
    assert_beta_enabled('emis_prefill', true)
  end

  it 'accepts register request' do
    post '/v0/beta_registration/veteran_id_card', nil, auth_header
    expect(response).to be_success
    expect(response.body).to be_a(String)
    json = JSON.parse(response.body)
    expect(json['user']).to eq(user.email)
  end

  it 'accepts register request' do
    post '/v0/beta_registration/veteran_id_card', nil, auth_header
    get '/v0/beta_registration/veteran_id_card', nil, auth_header
    expect(response).to be_success
    json = JSON.parse(response.body)
    expect(json['user']).to eq(user.email)
  end

  it 'is reflected in beta_switch' do
    post '/v0/beta_registration/veteran_id_card', nil, auth_header
    expect(dummy_class.beta_enabled?(user.uuid, 'veteran_id_card')).to be_truthy
  end
end
