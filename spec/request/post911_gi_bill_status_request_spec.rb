# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Fetching Post 911 GI Bill Status', type: :request do
  include SchemaMatchers

  let(:token) { 'abracadabra-open-sesame' }

  context 'when an LOA 3 user is logged in' do
    let(:mhv_user) { build :mhv_user }

    before do
      Session.create(uuid: mhv_user.uuid, token: token)
      User.create(mhv_user)

      auth_header = { 'Authorization' => "Token token=#{token}" }
      get v0_post911_gi_bill_status_url, nil, auth_header
    end

    it 'GET /v0/post911_gi_bill_status returns proper json' do
      assert_response :success
      expect(response).to match_response_schema('post911_gi_bill_status', strict: false)
    end
  end
end
