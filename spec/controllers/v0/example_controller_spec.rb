# frozen_string_literal: true
require 'rails_helper'

RSpec.describe V0::ExampleController, type: :controller do
  context 'when not logged in' do
    it 'returns unauthorized' do
      get :welcome
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'when logged in' do
    let(:token) { 'abracadabra-open-sesame' }
    let(:auth_header) { ActionController::HttpAuthentication::Token.encode_credentials(token) }

    before(:each) do
      Session.create(uuid: '1234', token: token)
      User.create(
        uuid: '1234',
        email: 'test@test.com',
        first_name: 'John',
        middle_name: 'William',
        last_name: 'Smith',
        dob: Time.new(1980, 1, 1),
        ssn: '555-44-3333'
      )
    end

    it 'returns a welcome string with user email in it' do
      request.env['HTTP_AUTHORIZATION'] = auth_header
      get :welcome
      assert_response :success
      expect(JSON.parse(response.body)['message']).to eq('You are logged in as test@test.com')
    end
  end
end
