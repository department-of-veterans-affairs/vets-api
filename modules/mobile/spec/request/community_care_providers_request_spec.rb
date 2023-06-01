# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'community care providers', type: :request do
  include JsonSchemaMatchers

  before { iam_sign_in(user) }

  let(:user) { FactoryBot.build(:iam_user) }
  let(:json_body_headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }

  describe 'GET providers', :aggregate_failures do
    it 'returns 200 with paginated results' do
      VCR.use_cassette('mobile/facilities/ppms/community_clinics_near_user', match_requests_on: %i[method uri]) do
        params = { serviceType: 'podiatry' }
        get('/mobile/v0/community-care-providers', headers: iam_headers, params:)

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['data'].count).to eq(10)
      end
    end

    it 'matches schema' do
      VCR.use_cassette('mobile/facilities/ppms/community_clinics_near_user', match_requests_on: %i[method uri]) do
        params = { serviceType: 'podiatry' }
        get('/mobile/v0/community-care-providers', headers: iam_headers, params:)

        expect(response.body).to match_json_schema('community_care_providers')
      end
    end

    it 'forms meta data' do
      VCR.use_cassette('mobile/appointments/get_facilities', match_requests_on: %i[method uri]) do
        VCR.use_cassette('mobile/facilities/ppms/community_clinics_near_facility', match_requests_on: %i[method uri]) do
          params = { serviceType: 'podiatry', facilityId: '442' }
          get('/mobile/v0/community-care-providers', headers: iam_headers, params:)

          expect(response.parsed_body['meta']).to eq(
            { 'pagination' => { 'currentPage' => 1, 'perPage' => 10, 'totalPages' => 1, 'totalEntries' => 10 } }
          )
        end
      end
    end

    context 'when no serviceType is provided' do
      it 'returns 400 with an error message' do
        get '/mobile/v0/community-care-providers', headers: iam_headers
        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body.dig('errors', 0, 'detail')).to eq('"" is not a valid value for "serviceType"')
      end
    end

    context 'when invalid serviceType is provided' do
      it 'returns 400 with an error message' do
        get '/mobile/v0/community-care-providers', headers: iam_headers, params: { serviceType: 'toe surgery' }
        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body.dig('errors', 0, 'detail')).to eq(
          '"toe surgery" is not a valid value for "serviceType"'
        )
      end
    end

    context 'when no providers are within the search parameters' do
      it 'returns an empty list' do
        VCR.use_cassette('mobile/facilities/ppms/community_clinics_empty_search', match_requests_on: %i[method uri]) do
          params = { serviceType: 'podiatry' }
          get('/mobile/v0/community-care-providers', headers: iam_headers, params:)
          expect(response).to have_http_status(:success)
          expect(response.parsed_body['data']).to eq([])
        end
      end
    end

    context 'when no facility id is provided' do
      it 'returns a list of providers based on the user\'s home address' do
        VCR.use_cassette('mobile/facilities/ppms/community_clinics_near_user', match_requests_on: %i[method uri]) do
          params = { serviceType: 'podiatry' }
          get('/mobile/v0/community-care-providers', headers: iam_headers, params:)
          expect(response).to have_http_status(:success)
          expect(response.parsed_body['data'].count).to eq(10)
        end
      end

      context 'when the user has no home address' do
        it 'returns 422 with error message' do
          VCR.use_cassette('mobile/facilities/ppms/community_clinics_near_user', match_requests_on: %i[method uri]) do
            address = user.vet360_contact_info.residential_address
            address.latitude = nil
            address.longitude = nil

            params = { serviceType: 'podiatry' }
            get('/mobile/v0/community-care-providers', headers: iam_headers, params:)
            expect(response).to have_http_status(:unprocessable_entity)
            expect(response.parsed_body.dig('errors', 0, 'detail')).to eq('User has no home latitude and longitude')
          end
        end
      end
    end

    context 'when a facility id is provided' do
      it 'requests community care clinics near the facility' do
        VCR.use_cassette('mobile/appointments/get_facilities', match_requests_on: %i[method uri]) do
          VCR.use_cassette('mobile/facilities/ppms/community_clinics_near_facility',
                           match_requests_on: %i[method uri]) do
            params = { facilityId: '442', serviceType: 'podiatry' }
            get('/mobile/v0/community-care-providers', headers: iam_headers, params:)
            expect(response).to have_http_status(:success)
          end
        end
      end

      context 'when facility id is not found' do
        it 'returns not found with a helpful error message' do
          VCR.use_cassette('mobile/lighthouse_health/get_facilities_empty', match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/facilities/ppms/community_clinics_near_facility',
                             match_requests_on: %i[method uri]) do
              params = { facilityId: '442', serviceType: 'podiatry' }
              get('/mobile/v0/community-care-providers', headers: iam_headers, params:)

              expect(response).to have_http_status(:not_found)
              expect(response.parsed_body.dig('errors', 0, 'detail')).to eq(
                'The record identified by 442 could not be found'
              )
            end
          end
        end
      end
    end
  end
end
