# frozen_string_literal: true

require 'rails_helper'
require 'support/error_details'

RSpec.describe 'email', type: :request do
  include SchemaMatchers
  include ErrorDetails

  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:user) { build(:user, :loa3) }

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
  end

  describe 'GET /v0/profile/email' do
    context 'with a 200 response' do
      it 'should match the email schema' do
        VCR.use_cassette('evss/pciu/email') do
          get '/v0/profile/email', nil, auth_header

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('email_address_response')
        end
      end
    end

    context 'with a 400 response' do
      it 'should match the errors schema' do
        VCR.use_cassette('evss/pciu/email_status_400') do
          get '/v0/profile/email', nil, auth_header

          expect(response).to have_http_status(:bad_request)
          expect(response).to match_response_schema('errors')
        end
      end
    end

    context 'with a 403 response' do
      it 'should return a forbidden response' do
        VCR.use_cassette('evss/pciu/email_status_403') do
          get '/v0/profile/email', nil, auth_header

          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    context 'with a 500 response' do
      it 'should match the errors schema' do
        VCR.use_cassette('evss/pciu/email_status_500') do
          get '/v0/profile/email', nil, auth_header

          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('errors')
        end
      end
    end

    context 'when authorization requirements are not met' do
      before do
        user = build(:unauthorized_evss_user, :loa3)
        Session.create(uuid: user.uuid, token: token)
        User.create(user)
      end

      it 'should match the errors schema', :aggregate_failures do
        get '/v0/profile/email', nil, auth_header

        expect(response).to have_http_status(:forbidden)
        expect(response).to match_response_schema('errors')
      end

      it 'should include the missing values in the response detail', :aggregate_failures do
        get '/v0/profile/email', nil, auth_header

        expect(details_for(response)).to include 'corp_id'
        expect(details_for(response)).to include 'edipi'
      end
    end
  end

  describe 'POST /v0/profile/email' do
    let(:email_address) { build(:email_address) }

    context 'with a 200 response' do
      it 'should match the email address schema', :aggregate_failures do
        VCR.use_cassette('evss/pciu/post_email_address') do
          post(
            '/v0/profile/email',
            email_address.to_json,
            auth_header.update(
              'Content-Type' => 'application/json', 'Accept' => 'application/json'
            )
          )

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('email_address_response')
        end
      end
    end

    context 'with a missing email' do
      it 'should match the errors schema', :aggregate_failures do
        email_address = build :email_address, email: ''

        post(
          '/v0/profile/email',
          email_address.to_json,
          auth_header.update(
            'Content-Type' => 'application/json', 'Accept' => 'application/json'
          )
        )

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_response_schema('errors')
        expect(errors_for(response)).to include "email - can't be blank"
      end
    end

    context 'with an invalid email' do
      it 'should match the errors schema', :aggregate_failures do
        email_address = build :email_address, email: 'johngmail.com'

        post(
          '/v0/profile/email',
          email_address.to_json,
          auth_header.update(
            'Content-Type' => 'application/json', 'Accept' => 'application/json'
          )
        )

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_response_schema('errors')
        expect(errors_for(response)).to include 'email - is invalid'
      end
    end

    context 'with a 400 response' do
      it 'should match the errors schema', :aggregate_failures do
        VCR.use_cassette('evss/pciu/post_email_address_status_400') do
          post(
            '/v0/profile/email',
            email_address.to_json,
            auth_header.update(
              'Content-Type' => 'application/json', 'Accept' => 'application/json'
            )
          )

          expect(response).to have_http_status(:bad_request)
          expect(response).to match_response_schema('errors')
        end
      end
    end

    context 'with a 403 response' do
      it 'should return a forbidden response' do
        VCR.use_cassette('evss/pciu/post_email_address_status_403') do
          post(
            '/v0/profile/email',
            email_address.to_json,
            auth_header.update(
              'Content-Type' => 'application/json', 'Accept' => 'application/json'
            )
          )

          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    context 'with a 500 response' do
      it 'should match the errors schema', :aggregate_failures do
        VCR.use_cassette('evss/pciu/post_email_address_status_500') do
          post(
            '/v0/profile/email',
            email_address.to_json,
            auth_header.update(
              'Content-Type' => 'application/json', 'Accept' => 'application/json'
            )
          )

          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('errors')
        end
      end
    end

    context 'when authorization requirements are not met' do
      before do
        user = build(:unauthorized_evss_user, :loa3)
        Session.create(uuid: user.uuid, token: token)
        User.create(user)
      end

      it 'should match the errors schema', :aggregate_failures do
        post(
          '/v0/profile/email',
          email_address.to_json,
          auth_header.update(
            'Content-Type' => 'application/json', 'Accept' => 'application/json'
          )
        )

        expect(response).to have_http_status(:forbidden)
        expect(response).to match_response_schema('errors')
      end

      it 'should include the missing values in the response detail', :aggregate_failures do
        post(
          '/v0/profile/email',
          email_address.to_json,
          auth_header.update(
            'Content-Type' => 'application/json', 'Accept' => 'application/json'
          )
        )

        expect(details_for(response)).to include 'corp_id'
        expect(details_for(response)).to include 'edipi'
      end
    end
  end
end
