# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Form526 Opt In Endpoint', type: :request do
  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:user) { build(:user, :loa3) }
  let(:email) { { 'email' => 'test@adhocteam.us' } }

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
  end

  it 'returns a 200' do
    post '/v0/form526_opt_in', email, auth_header
    expect(response).to have_http_status(:ok)
  end

  it 'returns the email' do
    post '/v0/form526_opt_in', email, auth_header
    expect(response).to be_success
    expect(response.body).to be_a(String)
    json = JSON.parse(response.body)
    expect(json['data']['attributes']['email']).to eq(email['email'])
  end

  it 'creates a table entry' do
    post '/v0/form526_opt_in', email, auth_header
    expect(Form526OptIn.find_by(user_uuid: user.uuid).present?).to eq(true)
  end

  it 'updates table entry if called again' do
    post '/v0/form526_opt_in', email, auth_header
    post '/v0/form526_opt_in', { 'email' => 'test2@adhocteam.us' }, auth_header

    expect(Form526OptIn.find_by(user_uuid: user.uuid).email).to eq('test2@adhocteam.us')
  end
end
