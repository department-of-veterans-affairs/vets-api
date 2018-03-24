# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Appeals Status', type: :request do
  include SchemaMatchers

  let(:session) { Session.create(uuid: user.uuid) }

  context 'with a loa1 user' do
    let(:user) { FactoryBot.create(:user, :loa1, ssn: '111223333') }

    it 'returns a forbidden error' do
      get '/v0/appeals', nil, 'Authorization' => "Token token=#{session.token}"
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'with a loa3 user without a ssn' do
    let(:user) { FactoryBot.create(:user, :loa1, ssn: nil) }

    it 'returns a forbidden error' do
      get '/v0/appeals', nil, 'Authorization' => "Token token=#{session.token}"
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'with a loa3 user' do
    let(:user) { FactoryBot.create(:user, :loa3, ssn: '111223333') }

    context 'with a valid response' do
      it 'returns a successful response' do
        VCR.use_cassette('appeals/appeals') do
          get '/v0/appeals', nil, 'Authorization' => "Token token=#{session.token}"
          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('appeals')
        end
      end
    end

    context 'with a not authorized response' do
      it 'returns a 502 and logs an error level message' do
        VCR.use_cassette('appeals/not_authorized') do
          expect_any_instance_of(Appeals::Service).to receive(:log_message_to_sentry).with(anything, :error, anything)
          get '/v0/appeals', nil, 'Authorization' => "Token token=#{session.token}"
          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('errors')
        end
      end
    end

    context 'with a not found response' do
      it 'returns a 404 and logs an info level message' do
        VCR.use_cassette('appeals/not_found') do
          expect_any_instance_of(Appeals::Service).to receive(:log_message_to_sentry).with(anything, :info, anything)
          get '/v0/appeals', nil, 'Authorization' => "Token token=#{session.token}"
          expect(response).to have_http_status(:not_found)
          expect(response).to match_response_schema('errors')
        end
      end
    end

    context 'with an unprocessible entity response' do
      it 'returns a 422 and logs an info level message' do
        VCR.use_cassette('appeals/invalid_ssn') do
          expect_any_instance_of(Appeals::Service).to receive(:log_message_to_sentry).with(anything, :info, anything)
          get '/v0/appeals', nil, 'Authorization' => "Token token=#{session.token}"
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response).to match_response_schema('errors')
        end
      end
    end

    context 'with a server error' do
      it 'returns a 502 and logs an error level message' do
        VCR.use_cassette('appeals/server_error') do
          expect_any_instance_of(Appeals::Service).to receive(:log_message_to_sentry).with(anything, :error, anything)
          get '/v0/appeals', nil, 'Authorization' => "Token token=#{session.token}"
          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('errors')
        end
      end
    end
  end
end
