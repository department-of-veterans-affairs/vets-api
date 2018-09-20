# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Disability Rating API endpoint', type: :request, skip_emis: true do
  include SchemaMatchers

  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:user) { build(:user, :loa3) }

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
  end

  context 'with valid emis responses' do
    it 'should return the current users service history with one episode' do
      VCR.use_cassette('evss/disability_compensation_form/rated_disabilities') do
        get '/services/veteran_verification/v0/disability_rating', nil, auth_header
        expect(response).to have_http_status(:ok)
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('disability_rating_response')
      end
    end
  end

  context 'with a 500 response' do
    it 'should return a bad gateway response' do
      VCR.use_cassette('evss/disability_compensation_form/rated_disabilities_500') do
        get '/v0/disability_compensation_form/rated_disabilities', nil, auth_header
        expect(response).to have_http_status(:bad_gateway)
        expect(response).to match_response_schema('evss_errors', strict: false)
      end
    end
  end

  context 'with a 403 unauthorized response' do
    it 'should return a not authorized response' do
      VCR.use_cassette('evss/disability_compensation_form/rated_disabilities_403') do
        get '/v0/disability_compensation_form/rated_disabilities', nil, auth_header
        expect(response).to have_http_status(:forbidden)
        expect(response).to match_response_schema('evss_errors', strict: false)
      end
    end
  end

  context 'with a generic 400 response' do
    it 'should return a bad request response' do
      VCR.use_cassette('evss/disability_compensation_form/rated_disabilities_400') do
        get '/v0/disability_compensation_form/rated_disabilities', nil, auth_header
        expect(response).to have_http_status(:bad_request)
        expect(response).to match_response_schema('evss_errors', strict: false)
      end
    end
  end
end
