# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'reference_data', type: :request do
  include SchemaMatchers

  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:user) { build(:user, :loa3) }

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
  end

  describe 'GET /v0/reference_data/countries' do
    context 'with a 200 evss response', vcr: { cassette_name: 'evss/reference_data/countries' } do
      it 'return a list of countries' do
        get '/v0/reference_data/countries', nil, auth_header
        expect(response).to have_http_status(:ok)
        # TODO : create or modify existing shema
        #expect(response).to match_response_schema('countries')
      end
    end

    context 'with a 401 tampered evss response', vcr: { cassette_name: 'evss/reference_data/401_tampered' } do
      it 'should return 500' do
        get '/v0/reference_data/countries', nil, auth_header
        expect(response).to have_http_status(:internal_server_error)
      end
    end

    context 'with a 401 no token evss reponse', vcr: { cassette_name: 'evss/reference_data/401_no_jwt_in_header' } do
      it 'should return 500' do
        get '/v0/reference_data/countries', nil, auth_header
        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end

  describe 'GET /v0/reference_data/states' do
  end
  describe 'GET /v0/reference_data/intake_sites' do
  end
  describe 'GET /v0/reference_data/disabilities' do
  end
  describe 'GET /v0/reference_data/treatment_centers' do
  end
end
