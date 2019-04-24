# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Form526 Opt In Endpoint', type: :request do
  let(:user) { build(:user, :loa3) }
  let(:email) { { 'email' => 'test@adhocteam.us' } }

  before(:each) { sign_in }

  it 'returns a 200' do
    post '/v0/form526_opt_in', params: email
    expect(response).to have_http_status(:ok)
  end

  it 'returns the email' do
    post '/v0/form526_opt_in', params: email
    expect(response).to be_success
    expect(response.body).to be_a(String)
    json = JSON.parse(response.body)
    expect(json['data']['attributes']['email']).to eq(email['email'])
  end

  it 'creates a table entry' do
    post '/v0/form526_opt_in', params: email
    expect(Form526OptIn.find_by(user_uuid: user.uuid).present?).to eq(true)
  end

  it 'updates table entry if called again' do
    post '/v0/form526_opt_in', params: email
    post '/v0/form526_opt_in', params: { 'email' => 'test2@adhocteam.us' }

    expect(Form526OptIn.find_by(user_uuid: user.uuid).email).to eq('test2@adhocteam.us')
  end
end
