# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Fetching profile data', type: :request do
  let(:token) { 'abracadabra-open-sesame' }

  context 'when an LOA 3 user is logged in' do
    let(:mvi_user) { build :mvi_user }
    it 'GET /profile - returns proper json' do
      Session.create(uuid: mvi_user.uuid, token: token)
      User.create(mvi_user)

      auth_header = { 'Authorization' => "Token token=#{token}" }
      get v0_profile_url, nil, auth_header

      assert_response :success

      expect(response).to match_response_schema('profile')
    end
  end

  context 'when an LOA 1 user is logged in' do
    let(:loa1_user) { build :loa1_user }

    it 'GET /profile - returns proper json' do
      Session.create(uuid: loa1_user.uuid, token: token)
      User.create(loa1_user)

      auth_header = { 'Authorization' => "Token token=#{token}" }
      get v0_profile_url, nil, auth_header

      assert_response :success

      expect(response).to match_response_schema('profile')
    end
  end
end
