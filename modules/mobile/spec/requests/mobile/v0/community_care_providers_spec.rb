# frozen_string_literal: true

require_relative '../../../support/helpers/rails_helper'
require_relative '../../../support/helpers/committee_helper'

RSpec.describe 'Mobile::V0::CommunityCareProviders', type: :request do
  include JsonSchemaMatchers
  include CommitteeHelper

  let!(:user) { sis_user(icn: '9000682') }
  let(:json_body_headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }

  before do
    allow(Flipper).to receive(:enabled?).with(:remove_pciu, instance_of(User)).and_return(false)
  end

  describe 'GET providers', :aggregate_failures do
    it 'returns 200 with paginated results' do
      VCR.use_cassette('mobile/facilities/ppms/community_clinics_near_user', match_requests_on: %i[method uri]) do
        params = { serviceType: 'podiatry' }
        get('/mobile/v0/community-care-providers', headers: sis_headers, params:)
        assert_schema_conform(200)
        expect(response.parsed_body['data'].count).to eq(10)
      end
    end

    it 'forms meta data' do
      VCR.use_cassette('lighthouse/facilities/v1/200_facilities', match_requests_on: %i[method uri]) do
        VCR.use_cassette('mobile/facilities/ppms/community_clinics_near_facility', match_requests_on: %i[method uri]) do
          params = { serviceType: 'podiatry', facilityId: '442' }
          get('/mobile/v0/community-care-providers', headers: sis_headers, params:)

          expect(response.parsed_body['meta']).to eq(
            { 'pagination' => { 'currentPage' => 1, 'perPage' => 10, 'totalPages' => 1, 'totalEntries' => 10 } }
          )
        end
      end
    end

    context 'when no serviceType is provided' do
      it 'returns 400 with an error message' do
        get '/mobile/v0/community-care-providers', headers: sis_headers
        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body.dig('errors', 0, 'detail')).to eq('"" is not a valid value for "serviceType"')
      end
    end

    context 'when invalid serviceType is provided' do
      it 'returns 400 with an error message' do
        get '/mobile/v0/community-care-providers', headers: sis_headers, params: { serviceType: 'toe surgery' }
        assert_schema_conform(400)
        expect(response.parsed_body.dig('errors', 0, 'detail')).to eq(
          '"toe surgery" is not a valid value for "serviceType"'
        )
      end
    end

    context 'when no providers are within the search parameters' do
      it 'returns an empty list' do
        VCR.use_cassette('mobile/facilities/ppms/community_clinics_empty_search', match_requests_on: %i[method uri]) do
          params = { serviceType: 'podiatry' }
          get('/mobile/v0/community-care-providers', headers: sis_headers, params:)
          assert_schema_conform(200)
          expect(response.parsed_body['data']).to eq([])
        end
      end
    end

    context 'when no facility id is provided' do
      it 'returns a list of providers based on the user\'s home address' do
        VCR.use_cassette('mobile/facilities/ppms/community_clinics_near_user', match_requests_on: %i[method uri]) do
          params = { serviceType: 'podiatry' }
          get('/mobile/v0/community-care-providers', headers: sis_headers, params:)
          assert_schema_conform(200)
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
            get('/mobile/v0/community-care-providers', headers: sis_headers, params:)
            assert_schema_conform(422)
            expect(response.parsed_body.dig('errors', 0, 'detail')).to eq('User has no home latitude and longitude')
          end
        end
      end
    end

    context 'when a facility id is provided' do
      it 'requests community care clinics near the facility' do
        VCR.use_cassette('lighthouse/facilities/v1/200_facilities', match_requests_on: %i[method uri]) do
          VCR.use_cassette('mobile/facilities/ppms/community_clinics_near_facility',
                           match_requests_on: %i[method uri]) do
            params = { facilityId: '442', serviceType: 'podiatry' }
            get('/mobile/v0/community-care-providers', headers: sis_headers, params:)
            assert_schema_conform(200)
          end
        end
      end

      context 'when facility id is not found' do
        it 'returns not found with a helpful error message' do
          VCR.use_cassette('mobile/lighthouse_health/get_facility_v1_empty_442', match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/facilities/ppms/community_clinics_near_facility',
                             match_requests_on: %i[method uri]) do
              params = { facilityId: '442', serviceType: 'podiatry' }
              get('/mobile/v0/community-care-providers', headers: sis_headers, params:)

              assert_schema_conform(404)
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
