# frozen_string_literal: true
require 'rails_helper'
require 'backend_services'

RSpec.describe 'Fetching user data', type: :request do
  let(:token) { 'abracadabra-open-sesame' }

  context 'when an LOA 3 user is logged in' do
    let(:mhv_user) { build :mhv_user }

    before do
      Session.create(uuid: mhv_user.uuid, token: token)
      User.create(mhv_user)

      auth_header = { 'Authorization' => "Token token=#{token}" }
      get v0_user_url, nil, auth_header
    end

    it 'GET /v0/user - returns proper json' do
      assert_response :success
      expect(response).to match_response_schema('user_loa3')
    end

    it 'gives me the list of available services' do
      expect(JSON.parse(response.body)['data']['attributes']['services'].sort).to eq(
        [
          BackendServices::FACILITIES,
          BackendServices::HCA,
          BackendServices::EDUCATION_BENEFITS,
          BackendServices::EVSS_CLAIMS,
          BackendServices::USER_PROFILE,
          BackendServices::RX,
          BackendServices::MESSAGING,
          BackendServices::HEALTH_RECORDS
        ].sort
      )
    end
  end

  context 'when an LOA 1 user is logged in' do
    let(:loa1_user) { build :loa1_user }

    before do
      Session.create(uuid: loa1_user.uuid, token: token)
      User.create(loa1_user)

      auth_header = { 'Authorization' => "Token token=#{token}" }
      get v0_user_url, nil, auth_header
    end

    it 'GET /v0/user - returns proper json' do
      assert_response :success
      expect(response).to match_response_schema('user_loa1')
    end

    it 'gives me the list of available services' do
      expect(JSON.parse(response.body)['data']['attributes']['services'].sort).to eq(
        [
          BackendServices::FACILITIES,
          BackendServices::HCA,
          BackendServices::EDUCATION_BENEFITS,
          BackendServices::USER_PROFILE
        ].sort
      )
    end
  end
end
