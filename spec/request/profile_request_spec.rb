# frozen_string_literal: true
require 'rails_helper'
require 'backend_services'

RSpec.describe 'Fetching profile data', type: :request do

  context 'when an LOA 3 user is logged in' do
    let(:session) { build :loa3_session }
    let(:user) { build :loa3_user, uuid: session.uuid, session: session }

    before do
      Session.create(session)
      User.create(user)

      auth_header = { 'Authorization' => "Token token=#{session.token}" }
      get v0_user_url, nil, auth_header
    end

    it 'GET /v0/user - returns proper json' do
      assert_response :success
      expect(response).to match_response_schema('profile')
    end

    it 'gives me the list of available services' do
      expect(JSON.parse(response.body)['data']['attributes']['services'].sort).to eq(
        [
          BackendServices::FACILITIES,
          BackendServices::HCA,
          BackendServices::EDUCATION_BENEFITS,
          BackendServices::DISABILITY_BENEFITS,
          BackendServices::USER_PROFILE,
          BackendServices::RX,
          BackendServices::MESSAGING
        ].sort
      )
    end
  end

  context 'when an LOA 1 user is logged in' do
    let(:session) { build :loa1_session }
    let(:user) { build :loa1_user, uuid: session.uuid, session: session }

    before do
      Session.create(session)
      User.create(user)

      auth_header = { 'Authorization' => "Token token=#{session.token}" }
      get v0_user_url, nil, auth_header
    end

    it 'GET /v0/user - returns proper json' do
      assert_response :success
      expect(response).to match_response_schema('profile')
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
