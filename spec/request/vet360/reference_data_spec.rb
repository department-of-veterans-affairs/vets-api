# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'profile reference data', type: :request do
  include SchemaMatchers

  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:user) { build(:user, :loa3) }

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
  end

  %i[countries states zipcodes].each do |endpoint|
    describe "GET /v0/profile/reference_data/#{endpoint}" do
      it 'should match the schema' do
        VCR.use_cassette("vet360/reference_data/#{endpoint}") do
          get("/v0/profile/reference_data/#{endpoint}", nil, auth_header)
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema("vet360/#{endpoint}")
        end
      end
    end
  end
end
