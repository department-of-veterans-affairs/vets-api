# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Fetching Post 911 GI Bill Status', type: :request do
  include SchemaMatchers

  let(:token) { 'abracadabra-open-sesame' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }

  context 'when an LOA 3 user is logged in' do
    let(:mhv_user) { build :mhv_user }

    before do
      Session.create(uuid: mhv_user.uuid, token: token)
      User.create(mhv_user)
    end

    it 'GET /v0/post911_gi_bill_status returns proper json' do
      VCR.use_cassette('evss/gi_bill_status/gi_bill_status') do
        get v0_post911_gi_bill_status_url, nil, auth_header
        assert_response :success
      end
    end
  end
end
