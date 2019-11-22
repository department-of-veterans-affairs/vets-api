# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'rating info', type: :request do
  include SchemaMatchers

  let(:user) { build(:disabilities_compensation_user) }
  let(:headers) { { 'CONTENT_TYPE' => 'application/json' } }

  before do
    sign_in_as(user)
  end

  describe 'GET /v0/disability_compensation_form/find_rating_info_pid' do
    context 'with a valid 200 evss response' do
      it 'matches the rating info schema' do
        VCR.use_cassette('evss/disability_compensation_form/find_rating_info_pid') do
          get('/v0/disability_compensation_form/find_rating_info_pid', params: nil, headers: headers)
          expect(response).to have_http_status(:ok)
          # expect(response).to match_response_schema('rating_info_response')
        end
      end
    end

    context 'with a 400 response' do
      it 'returns a bad gateway response' do
        VCR.use_cassette('evss/disability_compensation_form/find_rating_info_pid_400') do
          get('/v0/disability_compensation_form/find_rating_info_pid', params: nil, headers: headers)
          expect(response).to have_http_status(:bad_request)
          expect(response).to match_response_schema('evss_errors', strict: false)
        end
      end
    end

    context 'with a generic 500 response' do
      it 'returns a bad request response' do
        VCR.use_cassette('evss/disability_compensation_form/find_rating_info_pid_500') do
          get('/v0/disability_compensation_form/find_rating_info_pid', params: nil, headers: headers)
          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('evss_errors', strict: false)
        end
      end
    end

    context 'with a 403 unauthorized response' do
      let(:user) { build(:unauthorized_evss_user, :loa3) }

      it 'returns a forbidden response' do
        VCR.use_cassette('evss/disability_compensation_form/find_rating_info_pid_403') do
          get('/v0/disability_compensation_form/find_rating_info_pid', params: nil, headers: headers)
          expect(response).to have_http_status(:forbidden)
          expect(response).to match_response_schema('evss_errors', strict: false)
        end
      end
    end
  end
end
