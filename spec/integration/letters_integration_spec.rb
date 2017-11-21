# frozen_string_literal: true
require 'rails_helper'

describe 'letters integration test', type: :request, integration: true do
  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:user) { build(:user, :loa3) }

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
    Settings.evss.mock_letters = false
  end

  it "should have the title 'Links'" do
    get '/v0/letters', nil, auth_header
    puts response.inspect
    expect(response).to have_http_status(:ok)
  end
end
