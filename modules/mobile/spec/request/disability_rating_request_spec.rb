# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'Mobile Disability Rating API endpoint', type: :request do
  include JsonSchemaMatchers

  before do
    iam_sign_in
  end

  before(:all) do
    @original_cassette_dir = VCR.configure(&:cassette_library_dir)
    VCR.configure { |c| c.cassette_library_dir = 'modules/mobile/spec/support/vcr_cassettes' }
  end

  after(:all) { VCR.configure { |c| c.cassette_library_dir = @original_cassette_dir } }

  let(:expected_response) do
    {
      'data' => {
        'id' => '0',
        'type' => 'disabilityRating',
        'attributes' => {
          'combinedDisabilityRating' => 100,
          'individualRatings' => [
            {
              'decision' => 'Service Connected',
              'effectiveDate' => '2018-03-27T21:00:41.000+00:00',
              'ratingPercentage' => 100,
              'diagnosticText' => 'Diabetes mellitus0'
            },
            {
              'decision' => 'Service Connected',
              'effectiveDate' => '2018-03-27T21:00:41.000+00:00',
              'ratingPercentage' => 100,
              'diagnosticText' => 'Diabetes mellitus1'
            }
          ]
        }
      }
    }
  end

  describe 'Get /v0/disability-rating' do
    context 'with a valid 200 evss response' do
      it 'matches the rated disabilities schema' do
        VCR.use_cassette('profile/rating_info') do
          VCR.use_cassette('profile/rated_disabilities') do
            get '/mobile/v0/disability-rating', params: nil, headers: iam_headers
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)).to eq(expected_response)
            expect(response.body).to match_json_schema('disability_rating_response')
          end
        end
      end
    end

    context 'with a 500 response for individual ratings' do
      it 'returns a bad gateway response' do
        VCR.use_cassette('profile/rating_info') do
          VCR.use_cassette('profile/rated_disabilities_500') do
            get '/mobile/v0/disability-rating', params: nil, headers: iam_headers
            expect(response).to have_http_status(:bad_gateway)
            expect(response.body).to match_json_schema('evss_errors')
          end
        end
      end
    end

    context 'with a 500 response for combine rating' do
      it 'returns a bad gateway response' do
        VCR.use_cassette('profile/rating_info_500') do
          VCR.use_cassette('profile/rated_disabilities') do
            get '/mobile/v0/disability-rating', params: nil, headers: iam_headers
            expect(response).to have_http_status(:bad_gateway)
            expect(response.body).to match_json_schema('evss_errors')
          end
        end
      end
    end

    context 'with a 500 response for both' do
      it 'returns a bad gateway response' do
        VCR.use_cassette('profile/rating_info_500') do
          VCR.use_cassette('profile/rated_disabilities_500') do
            get '/mobile/v0/disability-rating', params: nil, headers: iam_headers
            expect(response).to have_http_status(:bad_gateway)
            expect(response.body).to match_json_schema('evss_errors')
          end
        end
      end
    end

    context 'with a 400 response for individual ratings' do
      it 'returns a not found response' do
        VCR.use_cassette('profile/rating_info') do
          VCR.use_cassette('profile/rated_disabilities_400') do
            get '/mobile/v0/disability-rating', params: nil, headers: iam_headers
            expect(response).to have_http_status(:not_found)
            expect(response.body).to match_json_schema('evss_errors')
          end
        end
      end
    end

    context 'with a 400 response for combine rating' do
      it 'returns a not found response' do
        VCR.use_cassette('profile/rating_info_400') do
          VCR.use_cassette('profile/rated_disabilities') do
            get '/mobile/v0/disability-rating', params: nil, headers: iam_headers
            expect(response).to have_http_status(:not_found)
            expect(response.body).to match_json_schema('evss_errors')
          end
        end
      end
    end

    context 'with a 400 response for both' do
      it 'returns a not found response' do
        VCR.use_cassette('profile/rating_info_400') do
          VCR.use_cassette('profile/rated_disabilities_400') do
            get '/mobile/v0/disability-rating', params: nil, headers: iam_headers
            expect(response).to have_http_status(:not_found)
            expect(response.body).to match_json_schema('evss_errors')
          end
        end
      end
    end

    context 'with a 403 response for individual ratings' do
      it 'returns a forbidden response' do
        VCR.use_cassette('profile/rating_info') do
          VCR.use_cassette('profile/rated_disabilities_403') do
            get '/mobile/v0/disability-rating', params: nil, headers: iam_headers
            expect(response).to have_http_status(:forbidden)
            expect(response.body).to match_json_schema('evss_errors')
          end
        end
      end
    end

    context 'with a 403 response for combine rating' do
      it 'returns a not found response' do
        VCR.use_cassette('profile/rating_info_403') do
          VCR.use_cassette('profile/rated_disabilities') do
            get '/mobile/v0/disability-rating', params: nil, headers: iam_headers
            expect(response).to have_http_status(:forbidden)
            expect(response.body).to match_json_schema('evss_errors')
          end
        end
      end
    end

    context 'with a 403 response for both' do
      it 'returns a not found response' do
        VCR.use_cassette('profile/rating_info_403') do
          VCR.use_cassette('profile/rated_disabilities_403') do
            get '/mobile/v0/disability-rating', params: nil, headers: iam_headers
            expect(response).to have_http_status(:forbidden)
            expect(response.body).to match_json_schema('evss_errors')
          end
        end
      end
    end
  end
end
