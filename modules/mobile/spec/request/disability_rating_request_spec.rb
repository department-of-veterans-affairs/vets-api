# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'Mobile Disability Rating API endpoint', type: :request do
  include JsonSchemaMatchers

  before do
    iam_sign_in
  end

  let(:expected_response) do
    {
      'data' => {
        'id' => '0',
        'type' => 'disabilityRating',
        'attributes' => {
          'combinedDisabilityRating' => 100,
          'combinedEffectiveDate' => '2019-01-01T00:00:00.000+00:00',
          'legalEffectiveDate' => '2018-12-31T00:00:00.000+00:00',
          'individualRatings' => [
            {
              'decision' => 'Service Connected',
              'effectiveDate' => '2005-01-01T00:00:00.000+00:00',
              'ratingPercentage' => 100,
              'diagnosticText' => 'Hearing Loss',
              'type' => '6100-Hearing loss'
            },
            {
              'decision' => 'Service Connected',
              'effectiveDate' => '2018-12-21T00:00:00.000+00:00',
              'ratingPercentage' => 10,
              'diagnosticText' => 'mental disorder',
              'type' => 'Schizophrenia, disorganized type'
            },
            {
              'decision' => 'Service Connected',
              'effectiveDate' => '2012-05-01T00:00:00.000+00:00',
              'ratingPercentage' => 10,
              'diagnosticText' => 'Allergies due to Hearing Loss',
              'type' => 'Limitation of flexion, knee'
            },
            {
              'decision' => 'Service Connected',
              'effectiveDate' => '2018-08-01T00:00:00.000+00:00',
              'ratingPercentage' => 0,
              'diagnosticText' => 'Sarcoma Soft-Tissue',
              'type' => 'Soft tissue sarcoma (neurogenic origin)'
            }
          ]
        }
      }
    }
  end

  context 'with valid bgs responses' do
    it 'returns all the current user disability ratings and overall service connected combined degree' do
      with_okta_configured do
        VCR.use_cassette('bgs/rating_web_service/rating_data') do
          get '/mobile/v0/disability-rating', params: nil, headers: iam_headers
          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(response).to match_json_schema('disability_rating_response')
          expect(JSON.parse(response.body)).to eq(expected_response)
        end
      end
    end
  end

  context 'with error bgs response' do
    it 'returns all the current user disability ratings and overall service connected combined degree' do
      with_okta_configured do
        VCR.use_cassette('bgs/rating_web_service/rating_data_not_found') do
          get '/mobile/v0/disability-rating', params: nil, headers: iam_headers
          expect(response).to have_http_status(:internal_server_error)
        end
      end
    end
  end
end
