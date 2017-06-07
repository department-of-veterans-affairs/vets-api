# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Fetching Post 911 Edu Enrollment Status', type: :request do
  include SchemaMatchers

  let(:token) { 'abracadabra-open-sesame' }
  let(:edu_enrollment) { build :education_enrollment }

  context 'when an LOA 3 user is logged in' do
    let(:mhv_user) { build :mhv_user }

    before do
      Session.create(uuid: mhv_user.uuid, token: token)
      User.create(mhv_user)

      auth_header = { 'Authorization' => "Token token=#{token}" }
      get v0_education_enrollment_url, nil, auth_header
    end

    it 'GET /v0/education_enrollment returns proper json' do
      assert_response :success
      expect(response).to match_response_schema('education_enrollment', strict: false)
    end
  end
end
