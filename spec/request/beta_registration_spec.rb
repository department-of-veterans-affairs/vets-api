# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Beta Registration Endpoint', type: :request do
  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:user) { build(:loa3_user) }

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
  end
  it 'returns 404 for unregistered user' do
    get '/v0/beta_registration/health_account', nil, auth_header
    expect(response).to have_http_status(:not_found)
  end

  it 'accepts register request' do
    post '/v0/beta_registration/health_account', nil, auth_header
    expect(response).to be_success
    expect(response.body).to be_a(String)
    json = JSON.parse(response.body)
    expect(json['user']).to eq(user.email)
  end

  it 'accepts register request' do
    post '/v0/beta_registration/health_account', nil, auth_header
    get '/v0/beta_registration/health_account', nil, auth_header
    expect(response).to be_success
    json = JSON.parse(response.body)
    expect(json['user']).to eq(user.email)
  end
end
