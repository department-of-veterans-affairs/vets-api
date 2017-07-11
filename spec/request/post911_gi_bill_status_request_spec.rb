# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Fetching Post 911 GI Bill Status', type: :request do
  include SchemaMatchers

  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:user) { build(:loa3_user) }

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
    Settings.evss.mock_gi_bill_status = false
  end

  context 'with a valid evss response' do
    it 'GET /v0/post911_gi_bill_status returns proper json' do
      VCR.use_cassette('evss/gi_bill_status/gi_bill_status') do
        get v0_post911_gi_bill_status_url, nil, auth_header
        expect(response).to match_response_schema('post911_gi_bill_status')
        assert_response :success
      end
    end
  end

  # TODO(AJD): this use case happens, 500 status but unauthorized message
  # check with evss that they shouldn't be returning 403 instead
  context 'with an 500 unauthorized response' do
    it 'should return a not authorized response' do
      VCR.use_cassette('evss/gi_bill_status/unauthorized') do
        get v0_post911_gi_bill_status_url, nil, auth_header
        expect(response).to have_http_status(:ok)
        expect(response).to match_response_schema('post911_gi_bill_status')
        expect(Oj.load(response.body).dig('meta', 'status')).to eq(
          Common::Client::ServiceStatus::RESPONSE_STATUS[:not_authorized]
        )
      end
    end
  end

  context 'with a 403 response' do
    it 'should return a not authorized response' do
      VCR.use_cassette('evss/gi_bill_status/gi_bill_status_403') do
        get v0_post911_gi_bill_status_url, nil, auth_header
        expect(response).to have_http_status(:ok)
        expect(response).to match_response_schema('post911_gi_bill_status')
        expect(Oj.load(response.body).dig('meta', 'status')).to eq(
          Common::Client::ServiceStatus::RESPONSE_STATUS[:not_authorized]
        )
      end
    end
  end

  context 'with a 500 evss response' do
    it 'should return a not found response' do
      VCR.use_cassette('evss/gi_bill_status/gi_bill_status_500') do
        get v0_post911_gi_bill_status_url, nil, auth_header
        expect(response).to have_http_status(:ok)
        expect(response).to match_response_schema('post911_gi_bill_status')
        expect(Oj.load(response.body).dig('meta', 'status')).to eq(
          Common::Client::ServiceStatus::RESPONSE_STATUS[:server_error]
        )
      end
    end
  end
end
