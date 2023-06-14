# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'Mobile Disability Rating API endpoint', type: :request do
  include JsonSchemaMatchers

  let(:user) { build(:disabilities_compensation_user) }
  let(:expected_single_response) do
    {
      'data' => {
        'id' => '0',
        'type' => 'disabilityRating',
        'attributes' => {
          'combinedDisabilityRating' => 100,
          'individualRatings' => [
            {
              'decision' => 'Service Connected',
              'effectiveDate' => '2018-03-27T00:00:00+00:00',
              'ratingPercentage' => 50,
              'diagnosticText' => 'Diabetes mellitus0'
            }
          ]
        }
      }
    }
  end
  let(:expected_multiple_response) do
    {
      'data' => {
        'id' => '0',
        'type' => 'disabilityRating',
        'attributes' => {
          'combinedDisabilityRating' => 100,
          'individualRatings' => [
            {
              'decision' => 'Service Connected',
              'effectiveDate' => '2018-03-27T00:00:00+00:00',
              'ratingPercentage' => 50,
              'diagnosticText' => 'Diabetes mellitus0'
            },
            {
              'decision' => 'Service Connected',
              'effectiveDate' => '2018-05-27T00:00:00+00:00',
              'ratingPercentage' => 50,
              'diagnosticText' => 'Hearing Loss'
            }
          ]
        }
      }
    }
  end

  before do
    allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('blahblech')
    token = 'blahblech'
    allow_any_instance_of(VeteranVerification::Configuration).to receive(:access_token).and_return(token)
    sign_in_as(user)

    Flipper.enable(:mobile_lighthouse_disability_rating, user)
  end

  after { Flipper.disable(:mobile_lighthouse_disability_ratings) }

  describe 'Get /v0/disability-rating' do
    context 'with a valid 200 lighthouse response' do
      context 'with a single individual rating' do
        it 'matches the rated disabilities schema' do
          VCR.use_cassette('mobile/lighthouse_disability_rating/introspect_active') do
            VCR.use_cassette('mobile/lighthouse_disability_rating/200_individual_response') do
              get '/mobile/v0/disability-rating', params: nil, headers: iam_headers
              expect(response).to have_http_status(:ok)
              expect(JSON.parse(response.body)).to eq(expected_single_response)
              expect(response.body).to match_json_schema('disability_rating_response')
            end
          end
        end
      end

      context 'with multiple individual rating' do
        it 'matches the rated disabilities schema' do
          VCR.use_cassette('mobile/lighthouse_disability_rating/introspect_active') do
            VCR.use_cassette('mobile/lighthouse_disability_rating/200_multiple_response') do
              get '/mobile/v0/disability-rating', params: nil, headers: iam_headers
              expect(response).to have_http_status(:ok)
              expect(JSON.parse(response.body)).to eq(expected_multiple_response)
              expect(response.body).to match_json_schema('disability_rating_response')
            end
          end
        end
      end
    end

    context 'with a valid response that includes service connected and not connected' do
      before do
        VCR.use_cassette('mobile/lighthouse_disability_rating/introspect_active') do
          VCR.use_cassette('mobile/lighthouse_disability_rating/200_Not_Connected_response') do
            get '/mobile/v0/disability-rating', params: nil, headers: iam_headers
          end
        end
      end

      it 'rates service connected disabilities as an integer' do
        service_connnected = response.parsed_body.dig('data', 'attributes', 'individualRatings')[0]
        expect(service_connnected).to eq({
                                           'decision' => 'Service Connected',
                                           'effectiveDate' => '2018-03-27T00:00:00+00:00',
                                           'ratingPercentage' => 50,
                                           'diagnosticText' => 'Diabetes mellitus0'
                                         })
      end

      it 'rates non service connected disabilities as null' do
        not_service_connnected = response.parsed_body.dig('data', 'attributes', 'individualRatings')[1]
        expect(not_service_connnected).to eq({
                                               'decision' => 'Not Service Connected',
                                               'effectiveDate' => '2018-03-27T00:00:00+00:00',
                                               'ratingPercentage' => 50,
                                               'diagnosticText' => 'Diabetes mellitus0'
                                             })
      end

      it 'matches the rated disabilities schema' do
        expect(response.body).to match_json_schema('disability_rating_response')
      end
    end

    context 'with a 500 response from upstream service' do
      it 'returns a bad gateway response' do
        VCR.use_cassette('mobile/lighthouse_disability_rating/introspect_active') do
          VCR.use_cassette('mobile/lighthouse_disability_rating/500_response') do
            get '/mobile/v0/disability-rating', params: nil, headers: iam_headers
            expect(response).to have_http_status(:internal_server_error)
            expect(response.body).to match_json_schema('lighthouse_errors')
            expect(response.parsed_body).to eq({ 'errors' =>
                                                   [{ 'timestamp' => '2023-02-13T17:38:36.551+00:00',
                                                      'status' => '500',
                                                      'error' => 'Internal Server Error',
                                                      'path' =>
                                                        '/veteran_verification/v2/disability_rating',
                                                      'code' => '500',
                                                      'title' =>
                                                        'Common::Exceptions::ExternalServerInternalServerError',
                                                      'detail' => 'Internal Server Error' }] })
          end
        end
      end
    end

    context 'with a 502 response from upstream service' do
      it 'returns a bad gateway response' do
        VCR.use_cassette('mobile/lighthouse_disability_rating/introspect_active') do
          VCR.use_cassette('mobile/lighthouse_disability_rating/502_response') do
            get '/mobile/v0/disability-rating', params: nil, headers: iam_headers
            expect(response).to have_http_status(:bad_gateway)
            expect(response.body).to match_json_schema('lighthouse_errors')
            expect(response.parsed_body).to eq({ 'errors' =>
                                                   [{ 'title' => 'Unexpected Response Body',
                                                      'detail' =>
                                                        'EMIS service responded with something other than veteran ' \
                                                        'status information.',
                                                      'code' => 'EMIS_STATUS502',
                                                      'status' => '502' }] })
          end
        end
      end
    end

    context 'with a 503 response from upstream service' do
      it 'returns a bad gateway response' do
        VCR.use_cassette('mobile/lighthouse_disability_rating/introspect_active') do
          VCR.use_cassette('mobile/lighthouse_disability_rating/503_response') do
            get '/mobile/v0/disability-rating', params: nil, headers: iam_headers
            expect(response).to have_http_status(:service_unavailable)
            expect(response.body).to match_json_schema('lighthouse_errors')
            expect(response.parsed_body).to eq({ 'errors' =>
                                                   [{ 'title' => 'Error title',
                                                      'detail' => 'Detailed error message',
                                                      'code' => '503',
                                                      'status' => '503' }] })
          end
        end
      end
    end

    context 'with a 400 response from upstream service' do
      it 'returns a not found response' do
        VCR.use_cassette('mobile/lighthouse_disability_rating/introspect_active') do
          VCR.use_cassette('mobile/lighthouse_disability_rating/400_response') do
            get '/mobile/v0/disability-rating', params: nil, headers: iam_headers
            expect(response).to have_http_status(:bad_request)
            expect(response.body).to match_json_schema('lighthouse_errors')
            expect(response.parsed_body).to eq({ 'errors' =>
                                                   [{ 'timestamp' => '2023-02-13T17:38:36.551+00:00',
                                                      'status' => '400',
                                                      'error' => 'Bad Request',
                                                      'path' =>
                                                        '/veteran_verification/v2/disability_rating',
                                                      'code' => '400',
                                                      'title' => 'Common::Exceptions::BadRequest',
                                                      'detail' => 'Bad Request' }] })
          end
        end
      end
    end

    context 'with a 401 response from upstream service' do
      it 'returns a 401 response' do
        VCR.use_cassette('mobile/lighthouse_disability_rating/introspect_active') do
          VCR.use_cassette('mobile/lighthouse_disability_rating/401_response') do
            get '/mobile/v0/disability-rating', params: nil, headers: iam_headers
            expect(response).to have_http_status(:unauthorized)
            expect(response.body).to match_json_schema('lighthouse_errors')
            expect(response.parsed_body).to eq({ 'errors' =>
                                                   [{ 'status' => '401',
                                                      'error' => 'Invalid Token.',
                                                      'path' =>
                                                        '/veteran_verification/v2/disability_rating',
                                                      'code' => '401',
                                                      'title' => 'Common::Exceptions::Unauthorized',
                                                      'detail' => 'Invalid Token.' }] })
          end
        end
      end
    end

    context 'with a 403 response from upstream service' do
      it 'returns a forbidden response' do
        VCR.use_cassette('mobile/lighthouse_disability_rating/introspect_active') do
          VCR.use_cassette('mobile/lighthouse_disability_rating/403_response') do
            get '/mobile/v0/disability-rating', params: nil, headers: iam_headers
            expect(response).to have_http_status(:forbidden)
            expect(response.body).to match_json_schema('lighthouse_errors')
            expect(response.parsed_body).to eq({ 'errors' =>
                                                   [{ 'status' => '403',
                                                      'error' => 'Token not granted requested scope.',
                                                      'path' =>
                                                        '/veteran_verification/v2/disability_rating',
                                                      'code' => '403',
                                                      'title' => 'Common::Exceptions::Forbidden',
                                                      'detail' => 'Token not granted requested scope.' }] })
          end
        end
      end
    end

    context 'with a 404 response from upstream service' do
      it 'returns a not found response' do
        VCR.use_cassette('mobile/lighthouse_disability_rating/introspect_active') do
          VCR.use_cassette('mobile/lighthouse_disability_rating/404_ICN_response') do
            get '/mobile/v0/disability-rating', params: nil, headers: iam_headers
            expect(response).to have_http_status(:not_found)
            expect(response.body).to match_json_schema('lighthouse_errors')
            expect(response.parsed_body).to eq({ 'errors' =>
                                                   [{ 'title' => 'Veteran not identifiable.',
                                                      'detail' => 'No data found for ICN.',
                                                      'code' => '404',
                                                      'status' => '404' }] })
          end
        end
      end
    end

    context 'with a 405 response from upstream service' do
      it 'returns a not found response' do
        VCR.use_cassette('mobile/lighthouse_disability_rating/introspect_active') do
          VCR.use_cassette('mobile/lighthouse_disability_rating/405_response') do
            get '/mobile/v0/disability-rating', params: nil, headers: iam_headers
            expect(response).to have_http_status(:method_not_allowed)
            expect(response.body).to match_json_schema('lighthouse_errors')
            expect(response.parsed_body).to eq({ 'errors' =>
                                                   [{ 'status' => '405',
                                                      'error' => 'Unknown.',
                                                      'path' => '/veteran_verification/v2/disability_rating',
                                                      'code' => '405',
                                                      'title' => 'Common::Exceptions::ServiceError',
                                                      'detail' => 'Unknown.' }] })
          end
        end
      end
    end

    context 'with a 413 response from upstream service' do
      it 'returns a not found response' do
        VCR.use_cassette('mobile/lighthouse_disability_rating/introspect_active') do
          VCR.use_cassette('mobile/lighthouse_disability_rating/413_response') do
            get '/mobile/v0/disability-rating', params: nil, headers: iam_headers
            expect(response).to have_http_status(:payload_too_large)
            expect(response.body).to match_json_schema('lighthouse_errors')
            expect(response.parsed_body).to eq({ 'errors' =>
                                                   [{ 'message' => 'Request size limit exceeded',
                                                      'status' => '413',
                                                      'code' => '413',
                                                      'title' => 'Common::Exceptions::PayloadTooLarge',
                                                      'detail' => 'Request size limit exceeded' }] })
          end
        end
      end
    end

    context 'with a 429 response from upstream service' do
      it 'returns a not found response' do
        VCR.use_cassette('mobile/lighthouse_disability_rating/introspect_active') do
          VCR.use_cassette('mobile/lighthouse_disability_rating/429_response') do
            get '/mobile/v0/disability-rating', params: nil, headers: iam_headers
            expect(response).to have_http_status(:too_many_requests)
            expect(response.body).to match_json_schema('lighthouse_errors')
            expect(response.parsed_body).to eq({ 'errors' =>
                                                   [{ 'title' => 'Too Many Requests',
                                                      'detail' =>
                                                        'The user has sent too many requests in a given amount of time',
                                                      'code' => '429',
                                                      'status' => '429' }] })
          end
        end
      end
    end
  end
end
