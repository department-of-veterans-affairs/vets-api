# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'letters', type: :request do
  include SchemaMatchers

  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:user) { build(:loa3_user) }

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
    Settings.evss.mock_letters = false
  end

  describe 'GET /v0/letters' do
    context 'with a valid evss response' do
      it 'should match the letters schema' do
        VCR.use_cassette('evss/letters/letters') do
          get '/v0/letters', nil, auth_header
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('letters')
        end
      end
    end

    # TODO(AJD): this use case happens, 500 status but unauthorized message
    # check with evss that they shouldn't be returning 403 instead
    context 'with an 500 unauthorized response' do
      it 'should return a not authorized response' do
        VCR.use_cassette('evss/letters/unauthorized') do
          get '/v0/letters', nil, auth_header
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('letters')
          expect(Oj.load(response.body).dig('meta', 'status')).to eq(
            Common::Client::ServiceStatus::RESPONSE_STATUS[:not_authorized]
          )
        end
      end
    end

    context 'with a 403 response' do
      it 'should return a not authorized response' do
        VCR.use_cassette('evss/letters/letters_403') do
          get '/v0/letters', nil, auth_header
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('letters')
          expect(Oj.load(response.body).dig('meta', 'status')).to eq(
            Common::Client::ServiceStatus::RESPONSE_STATUS[:not_authorized]
          )
        end
      end
    end

    context 'with a 500 response' do
      it 'should return a not found response' do
        VCR.use_cassette('evss/letters/letters_500') do
          get '/v0/letters', nil, auth_header
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('letters')
          expect(Oj.load(response.body).dig('meta', 'status')).to eq(
            Common::Client::ServiceStatus::RESPONSE_STATUS[:server_error]
          )
        end
      end
    end
  end

  describe 'GET /v0/letters/:id' do
    context 'with a valid evss response' do
      it 'should download a PDF' do
        VCR.use_cassette('evss/letters/download') do
          get '/v0/letters/commissary', nil, auth_header
          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'with a 404 evss response' do
      it 'should download a PDF' do
        VCR.use_cassette('evss/letters/download_404') do
          get '/v0/letters/comissary', nil, auth_header
          expect(response).to have_http_status(:bad_request)
        end
      end
    end
  end

  describe 'GET /v0/letters/beneficiary' do
    context 'with a valid evss response' do
      it 'should match the letter beneficiary schema' do
        VCR.use_cassette('evss/letters/beneficiary') do
          get '/v0/letters/beneficiary', nil, auth_header
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('letter_beneficiary')
        end
      end
    end
  end
end
