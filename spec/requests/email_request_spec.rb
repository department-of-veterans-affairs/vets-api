# frozen_string_literal: true

require 'rails_helper'
require 'support/error_details'

RSpec.describe 'email' do
  include SchemaMatchers
  include ErrorDetails

  let(:user) { build(:user, :loa3) }
  let(:headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }
  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  before { sign_in_as(user) }

  describe 'GET /v0/profile/email' do
    context 'with a 200 response' do
      it 'matches the email schema' do
        VCR.use_cassette('evss/pciu/email') do
          get '/v0/profile/email'

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('email_address_response')
        end
      end

      it 'matches the email schema when camel-inflected' do
        VCR.use_cassette('evss/pciu/email') do
          get '/v0/profile/email', headers: inflection_header

          expect(response).to have_http_status(:ok)
          expect(response).to match_camelized_response_schema('email_address_response')
        end
      end
    end

    context 'with a 400 response' do
      it 'matches the errors schema' do
        VCR.use_cassette('evss/pciu/email_status_400') do
          get '/v0/profile/email'

          expect(response).to have_http_status(:bad_request)
          expect(response).to match_response_schema('errors')
        end
      end

      it 'matches the errors schema when camel-inflected' do
        VCR.use_cassette('evss/pciu/email_status_400') do
          get '/v0/profile/email', headers: inflection_header

          expect(response).to have_http_status(:bad_request)
          expect(response).to match_camelized_response_schema('errors')
        end
      end
    end

    context 'with a 403 response' do
      it 'returns a forbidden response' do
        VCR.use_cassette('evss/pciu/email_status_403') do
          get '/v0/profile/email'

          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    context 'with a 500 response' do
      it 'matches the errors schema' do
        VCR.use_cassette('evss/pciu/email_status_500') do
          get '/v0/profile/email'

          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('errors')
        end
      end

      it 'matches the errors schema when camel-inflected' do
        VCR.use_cassette('evss/pciu/email_status_500') do
          get '/v0/profile/email', headers: inflection_header

          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_camelized_response_schema('errors')
        end
      end
    end

    context 'when authorization requirements are not met' do
      let(:user) { build(:unauthorized_evss_user, :loa3) }

      it 'matches the errors schema', :aggregate_failures do
        get '/v0/profile/email'

        expect(response).to have_http_status(:forbidden)
        expect(response).to match_response_schema('errors')
      end

      it 'matches the errors schema when camel-inflected', :aggregate_failures do
        get '/v0/profile/email', headers: inflection_header

        expect(response).to have_http_status(:forbidden)
        expect(response).to match_camelized_response_schema('errors')
      end

      it 'includes the missing values in the response detail', :aggregate_failures do
        get '/v0/profile/email'

        expect(error_details_for(response)).to include 'corp_id'
        expect(error_details_for(response)).to include 'edipi'
      end
    end
  end

  describe 'POST /v0/profile/email' do
    let(:email_address) { build(:email_address) }
    let(:headers_with_camel) { headers.merge(inflection_header) }

    context 'with a 200 response' do
      it 'matches the email address schema', :aggregate_failures do
        VCR.use_cassette('evss/pciu/post_email_address') do
          post('/v0/profile/email', params: email_address.to_json, headers:)

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('email_address_response')
        end
      end

      it 'matches the email address schema when camel-inflected', :aggregate_failures do
        VCR.use_cassette('evss/pciu/post_email_address') do
          post('/v0/profile/email', params: email_address.to_json, headers: headers_with_camel)

          expect(response).to have_http_status(:ok)
          expect(response).to match_camelized_response_schema('email_address_response')
        end
      end
    end

    context 'with a missing email' do
      it 'matches the errors schema', :aggregate_failures do
        email_address = build :email_address, email: ''

        post('/v0/profile/email', params: email_address.to_json, headers:)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_response_schema('errors')
        expect(errors_for(response)).to include "email - can't be blank"
      end

      it 'matches the errors schema when camel-inflected', :aggregate_failures do
        email_address = build :email_address, email: ''

        post('/v0/profile/email', params: email_address.to_json, headers: headers_with_camel)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_camelized_response_schema('errors')
        expect(errors_for(response)).to include "email - can't be blank"
      end
    end

    context 'with an invalid email' do
      it 'matches the errors schema', :aggregate_failures do
        email_address = build :email_address, email: 'johngmail.com'

        post('/v0/profile/email', params: email_address.to_json, headers:)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_response_schema('errors')
        expect(errors_for(response)).to include 'email - is invalid'
      end

      it 'matches the errors schema when camel-inflected', :aggregate_failures do
        email_address = build :email_address, email: 'johngmail.com'

        post('/v0/profile/email', params: email_address.to_json, headers: headers_with_camel)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_camelized_response_schema('errors')
        expect(errors_for(response)).to include 'email - is invalid'
      end
    end

    context 'with a 400 response' do
      it 'matches the errors schema', :aggregate_failures do
        VCR.use_cassette('evss/pciu/post_email_address_status_400') do
          post('/v0/profile/email', params: email_address.to_json, headers:)

          expect(response).to have_http_status(:bad_request)
          expect(response).to match_response_schema('errors')
        end
      end

      it 'matches the errors schema when camel-inflected', :aggregate_failures do
        VCR.use_cassette('evss/pciu/post_email_address_status_400') do
          post('/v0/profile/email', params: email_address.to_json, headers: headers_with_camel)

          expect(response).to have_http_status(:bad_request)
          expect(response).to match_camelized_response_schema('errors')
        end
      end
    end

    context 'with a 403 response' do
      it 'returns a forbidden response' do
        VCR.use_cassette('evss/pciu/post_email_address_status_403') do
          post('/v0/profile/email', params: email_address.to_json, headers:)

          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    context 'with a 500 response' do
      it 'matches the errors schema', :aggregate_failures do
        VCR.use_cassette('evss/pciu/post_email_address_status_500') do
          post('/v0/profile/email', params: email_address.to_json, headers:)

          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('errors')
        end
      end

      it 'matches the errors schema when camel-inflected', :aggregate_failures do
        VCR.use_cassette('evss/pciu/post_email_address_status_500') do
          post('/v0/profile/email', params: email_address.to_json, headers: headers_with_camel)

          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_camelized_response_schema('errors')
        end
      end
    end

    context 'when authorization requirements are not met' do
      let(:user) { build(:unauthorized_evss_user, :loa3) }

      it 'matches the errors schema', :aggregate_failures do
        post('/v0/profile/email', params: email_address.to_json, headers:)

        expect(response).to have_http_status(:forbidden)
        expect(response).to match_response_schema('errors')
      end

      it 'matches the errors schema when camel-inflected', :aggregate_failures do
        post('/v0/profile/email', params: email_address.to_json, headers: headers_with_camel)

        expect(response).to have_http_status(:forbidden)
        expect(response).to match_camelized_response_schema('errors')
      end

      it 'includes the missing values in the response detail', :aggregate_failures do
        post('/v0/profile/email', params: email_address.to_json, headers:)

        expect(error_details_for(response)).to include 'corp_id'
        expect(error_details_for(response)).to include 'edipi'
      end
    end
  end
end
