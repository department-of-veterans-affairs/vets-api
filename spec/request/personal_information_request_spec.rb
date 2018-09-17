# frozen_string_literal: true

require 'rails_helper'
require 'support/error_details'

RSpec.describe 'personal_information', type: :request do
  include SchemaMatchers
  include ErrorDetails

  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:user) { build(:user, :loa3) }

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
  end

  describe 'GET /v0/profile/personal_information' do
    context 'with a 200 response' do
      it 'should match the personal information schema' do
        VCR.use_cassette('mvi/find_candidate/valid') do
          get '/v0/profile/personal_information', nil, auth_header

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('personal_information_response')
        end
      end
    end

    context 'when MVI does not return a gender nor birthday', skip_mvi: true do
      it 'should match the errors schema', :aggregate_failures do
        VCR.use_cassette('mvi/find_candidate/missing_birthday_and_gender') do
          get '/v0/profile/personal_information', nil, auth_header

          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('errors')
        end
      end

      it 'should include the correct error code' do
        VCR.use_cassette('mvi/find_candidate/missing_birthday_and_gender') do
          get '/v0/profile/personal_information', nil, auth_header

          expect(error_details_for(response, key: 'code')).to eq 'MVI_BD502'
        end
      end
    end
  end
end
