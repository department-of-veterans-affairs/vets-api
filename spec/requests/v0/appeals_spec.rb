# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::Appeals', type: :request do
  include SchemaMatchers

  appeals_endpoint = '/v0/appeals'

  before { sign_in_as(user) }

  context 'with a loa1 user' do
    let(:user) { create(:user, :loa1, ssn: '111223333') }

    it 'returns a forbidden error' do
      get appeals_endpoint
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'with a loa3 user without a ssn' do
    let(:user) { create(:user, :loa1, ssn: nil) }

    it 'returns a forbidden error' do
      get appeals_endpoint
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'with a loa3 user' do
    let(:user) { create(:user, :loa3, ssn: '111223333') }

    context 'with a valid response' do
      it 'returns a successful response' do
        VCR.use_cassette('caseflow/appeals') do
          get appeals_endpoint
          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('appeals')
        end
      end
    end

    context 'with a not authorized response' do
      it 'returns a 502 and logs an error level message' do
        VCR.use_cassette('caseflow/not_authorized') do
          get appeals_endpoint
          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('errors')
        end
      end
    end

    context 'with a not found response' do
      it 'returns a 404 and logs an info level message' do
        VCR.use_cassette('caseflow/not_found') do
          get appeals_endpoint
          expect(response).to have_http_status(:not_found)
          expect(response).to match_response_schema('errors')
        end
      end
    end

    context 'with an unprocessible entity response' do
      it 'returns a 422 and logs an info level message' do
        VCR.use_cassette('caseflow/invalid_ssn') do
          get appeals_endpoint
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response).to match_response_schema('errors')
        end
      end
    end

    context 'with a server error' do
      it 'returns a 502 and logs an error level message' do
        VCR.use_cassette('caseflow/server_error') do
          get appeals_endpoint
          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('errors')
        end
      end
    end

    context 'with an invalid JSON body in the response' do
      it 'returns a 502 and logs an error level message' do
        VCR.use_cassette('caseflow/invalid_body') do
          get appeals_endpoint
          expect(response).to have_http_status(:internal_server_error)
        end
      end
    end

    context 'with a null eta' do
      it 'returns a successful response' do
        VCR.use_cassette('caseflow/appeals_null_eta') do
          get appeals_endpoint
          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('appeals')
        end
      end
    end

    context 'with no alert details due_date' do
      it 'returns a successful response' do
        VCR.use_cassette('caseflow/appeals_no_alert_details_due_date') do
          get appeals_endpoint
          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('appeals')
        end
      end
    end
  end
end
