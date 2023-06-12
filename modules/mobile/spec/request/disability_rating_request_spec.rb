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
  end
end
