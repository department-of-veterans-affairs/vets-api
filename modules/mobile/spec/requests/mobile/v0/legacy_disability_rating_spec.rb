# frozen_string_literal: true

require_relative '../../../support/helpers/rails_helper'

require 'evss/disability_compensation_form/service_unavailable_exception'

RSpec.describe 'Mobile::V0::DisabilityRating', type: :request do
  include JsonSchemaMatchers

  before do
    Flipper.disable(:mobile_lighthouse_disability_ratings)
  end

  let!(:user) { sis_user }
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
    context 'user without access' do
      let!(:user) { sis_user(participant_id: nil) }

      it 'returns 403' do
        get '/mobile/v0/disability-rating', params: nil, headers: sis_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with a valid 200 evss response' do
      it 'matches the rated disabilities schema' do
        VCR.use_cassette('mobile/profile/rating_info') do
          VCR.use_cassette('mobile/profile/rated_disabilities') do
            get '/mobile/v0/disability-rating', params: nil, headers: sis_headers
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)).to eq(expected_response)
          end
        end
      end
    end

    context 'with a valid response that includes service connected and not connected' do
      before do
        VCR.use_cassette('mobile/profile/rating_info') do
          VCR.use_cassette('mobile/profile/rated_disabilities_mixed_service_connected') do
            get '/mobile/v0/disability-rating', params: nil, headers: sis_headers
          end
        end
      end

      it 'rates service connected disabilities as an integer' do
        service_connnected = response.parsed_body.dig('data', 'attributes', 'individualRatings')[1]
        expect(service_connnected).to eq({
                                           'decision' => 'Service Connected',
                                           'effectiveDate' => '2012-05-01T05:00:00.000+00:00',
                                           'ratingPercentage' => 10,
                                           'diagnosticText' => nil
                                         })
      end

      it 'rates non service connected disabilities as null' do
        not_service_connnected = response.parsed_body.dig('data', 'attributes', 'individualRatings').first
        expect(not_service_connnected).to eq({
                                               'decision' => 'Not Service Connected',
                                               'effectiveDate' => nil,
                                               'ratingPercentage' => nil,
                                               'diagnosticText' => nil
                                             })
      end
    end

    context 'with a 500 response for individual ratings' do
      it 'returns a bad gateway response' do
        VCR.use_cassette('mobile/profile/rating_info') do
          VCR.use_cassette('mobile/profile/rated_disabilities_500') do
            get '/mobile/v0/disability-rating', params: nil, headers: sis_headers
            expect(response).to have_http_status(:bad_gateway)
            expect(response.body).to match_json_schema('evss_errors')
          end
        end
      end
    end

    context 'with a 500 response for combine rating' do
      it 'returns a bad gateway response' do
        VCR.use_cassette('mobile/profile/rating_info_500') do
          VCR.use_cassette('mobile/profile/rated_disabilities') do
            get '/mobile/v0/disability-rating', params: nil, headers: sis_headers
            expect(response).to have_http_status(:bad_gateway)
            expect(response.body).to match_json_schema('evss_errors')
          end
        end
      end
    end

    context 'with a 500 response for both' do
      it 'returns a bad gateway response' do
        VCR.use_cassette('mobile/profile/rating_info_500') do
          VCR.use_cassette('mobile/profile/rated_disabilities_500') do
            get '/mobile/v0/disability-rating', params: nil, headers: sis_headers
            expect(response).to have_http_status(:bad_gateway)
            expect(response.body).to match_json_schema('evss_errors')
          end
        end
      end
    end

    context 'with a 400 response for individual ratings' do
      it 'returns a not found response' do
        VCR.use_cassette('mobile/profile/rating_info') do
          VCR.use_cassette('mobile/profile/rated_disabilities_400') do
            get '/mobile/v0/disability-rating', params: nil, headers: sis_headers
            expect(response).to have_http_status(:not_found)
            expect(response.body).to match_json_schema('evss_errors')
          end
        end
      end
    end

    context 'with a 400 response for combine rating' do
      it 'returns a not found response' do
        VCR.use_cassette('mobile/profile/rating_info_400') do
          VCR.use_cassette('mobile/profile/rated_disabilities') do
            get '/mobile/v0/disability-rating', params: nil, headers: sis_headers
            expect(response).to have_http_status(:not_found)
            expect(response.body).to match_json_schema('evss_errors')
          end
        end
      end
    end

    context 'with a 400 response for both' do
      it 'returns a not found response' do
        VCR.use_cassette('mobile/profile/rating_info_400') do
          VCR.use_cassette('mobile/profile/rated_disabilities_400') do
            get '/mobile/v0/disability-rating', params: nil, headers: sis_headers
            expect(response).to have_http_status(:not_found)
            expect(response.body).to match_json_schema('evss_errors')
          end
        end
      end
    end

    context 'with a 403 response for individual ratings' do
      it 'returns a forbidden response' do
        VCR.use_cassette('mobile/profile/rating_info') do
          VCR.use_cassette('mobile/profile/rated_disabilities_403') do
            get '/mobile/v0/disability-rating', params: nil, headers: sis_headers
            expect(response).to have_http_status(:forbidden)
            expect(response.body).to match_json_schema('evss_errors')
          end
        end
      end
    end

    context 'with a 403 response for combine rating' do
      it 'returns a not found response' do
        VCR.use_cassette('mobile/profile/rating_info_403') do
          VCR.use_cassette('mobile/profile/rated_disabilities') do
            get '/mobile/v0/disability-rating', params: nil, headers: sis_headers
            expect(response).to have_http_status(:forbidden)
            expect(response.body).to match_json_schema('evss_errors')
          end
        end
      end
    end

    context 'with a 403 response for both' do
      it 'returns a not found response' do
        VCR.use_cassette('mobile/profile/rating_info_403') do
          VCR.use_cassette('mobile/profile/rated_disabilities_403') do
            get '/mobile/v0/disability-rating', params: nil, headers: sis_headers
            expect(response).to have_http_status(:forbidden)
            expect(response.body).to match_json_schema('evss_errors')
          end
        end
      end
    end

    context 'with an EVSS::DisabilityCompensationForm::ServiceUnavailable error' do
      before do
        allow_any_instance_of(EVSS::DisabilityCompensationForm::Service)
          .to receive(:get_rated_disabilities)
          .and_raise(EVSS::DisabilityCompensationForm::ServiceUnavailableException)
      end

      it 'raises backend service exception' do
        VCR.use_cassette('mobile/profile/rating_info') do
          VCR.use_cassette('mobile/profile/rated_disabilities') do
            get '/mobile/v0/disability-rating', params: nil, headers: sis_headers
            expect(response).to have_http_status(:bad_gateway)
            expect(response.body).to match_json_schema('evss_errors')
            expect(response.parsed_body).to eq({ 'errors' =>
                                                   [{ 'title' => 'Bad Gateway',
                                                      'detail' =>
                                                        'Received an an invalid response from the upstream server',
                                                      'code' => 'MOBL_502_upstream_error',
                                                      'status' => '502' }] })
          end
        end
      end
    end
  end
end
