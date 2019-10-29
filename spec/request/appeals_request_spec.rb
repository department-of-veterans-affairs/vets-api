# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Appeals', type: :request do
  include SchemaMatchers

  before { sign_in_as(user) }

  uuid = '1234567890'

  shared_context 'with user' do |options|
    using_ssn = options[:without_ssn] ? nil : '111223333'
    let(:user) { FactoryBot.create(:user, options[:user], ssn: using_ssn )}
  end

  describe 'show higher level review' do
    context 'with an loa1 user' do
      include_context 'with user', user: :loa1

      it 'returns a forbidden error' do
        get "/v0/appeals/higher_level_reviews/#{uuid}"
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with an loa3 user' do
      include_context 'with user', user: :loa3
      
      context 'with a valid response' do
        it 'returns a successful response' do
          VCR.use_cassette('appeals/higher_level_review') do
            get "/v0/appeals/higher_level_reviews/#{uuid}"
            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(response).to match_response_schema('higher_level_review')
          end
        end
      end
    end
  end

  describe 'show intake status' do
    context 'using loa1 user' do
      include_context 'with user', user: :loa1

      it 'returns a forbidden error' do
        get "/v0/appeals/higher_level_reviews/intake_status/#{uuid}"
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'using loa3 user' do
      include_context 'with user', user: :loa3

      context 'with a valid response' do
        it 'returns a successful response' do
          VCR.use_cassette('appeals/intake_status') do
            get "/v0/appeals/higher_level_reviews/intake_status/#{uuid}"
            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(response).to match_response_schema('intake_status')
          end
        end
      end
    end
  end

  context 'with a loa1 user' do
    include_context 'with user', user: :loa1

    it 'returns a forbidden error' do
      get '/v0/appeals'
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'with a loa3 user without a ssn' do
    include_context 'with user', user: :loa3, without_ssn: true

    it 'returns a forbidden error' do
      get '/v0/appeals'
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'with a loa3 user' do
    include_context 'with user', user: :loa3, without_ssn: true

    context 'with a valid response' do
      it 'returns a successful response' do
        VCR.use_cassette('appeals/appeals') do
          get '/v0/appeals'
          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('appeals')
        end
      end
    end

    context 'with a not authorized response' do
      it 'returns a 502 and logs an error level message' do
        VCR.use_cassette('appeals/not_authorized') do
          get '/v0/appeals'
          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('errors')
        end
      end
    end

    context 'with a not found response' do
      it 'returns a 404 and logs an info level message' do
        VCR.use_cassette('appeals/not_found') do
          get '/v0/appeals'
          expect(response).to have_http_status(:not_found)
          expect(response).to match_response_schema('errors')
        end
      end
    end

    context 'with an unprocessible entity response' do
      it 'returns a 422 and logs an info level message' do
        VCR.use_cassette('appeals/invalid_ssn') do
          get '/v0/appeals'
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response).to match_response_schema('errors')
        end
      end
    end

    context 'with a server error' do
      it 'returns a 502 and logs an error level message' do
        VCR.use_cassette('appeals/server_error') do
          get '/v0/appeals'
          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('errors')
        end
      end
    end

    context 'with an invalid JSON body in the response' do
      it 'returns a 502 and logs an error level message' do
        VCR.use_cassette('appeals/invalid_body') do
          get '/v0/appeals'
          expect(response).to have_http_status(:internal_server_error)
        end
      end
    end

    context 'with a null eta' do
      it 'returns a successful response' do
        VCR.use_cassette('appeals/appeals_null_eta') do
          get '/v0/appeals'
          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('appeals')
        end
      end
    end

    context 'with no alert details due_date' do
      it 'returns a successful response' do
        VCR.use_cassette('appeals/appeals_no_alert_details_due_date') do
          get '/v0/appeals'
          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('appeals')
        end
      end
    end
  end
end
