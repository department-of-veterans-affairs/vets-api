# frozen_string_literal: true
require 'rails_helper'

RSpec.describe V0::UsersController, type: :controller do
  context 'when not logged in' do
    it 'returns unauthorized' do
      get :show
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
        last_name: 'Smith',
        birth_date: Time.new(1980, 1, 1).utc,
        ssn: '555443333'
      )
    end

    it 'returns a JSON user profile' do
      request.env['HTTP_AUTHORIZATION'] = auth_header
      get :show
      assert_response :success

      json = JSON.parse(response.body)

      expect(json['uuid']).to eq('1234')
      expect(json['email']).to eq('test@test.com')
    end
  end
end
