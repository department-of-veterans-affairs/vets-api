# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'letters', type: :request do
  include JsonSchemaMatchers
  before { iam_sign_in }

  let(:expected_body) do
    {
        'data' => {
            'id' => '3097e489-ad75-5746-ab1a-e0aabc1b426a',
            'type' => 'letters',
            'attributes' => {
                'fullName' => 'MARK WEBB',
                'letters' =>
                    [
                        {
                            'name' => 'Commissary Letter',
                            'letterType' => 'commissary'
                        },
                        {
                            'name' => 'Proof of Service Letter',
                            'letterType' => 'proof_of_service'
                        },
                        {
                            'name' => 'Proof of Creditable Prescription Drug Coverage Letter',
                            'letterType' => 'medicare_partd'
                        },
                        {
                            'name' => 'Proof of Minimum Essential Coverage Letter',
                            'letterType' => 'minimum_essential_coverage'
                        },
                        {
                            'name' => 'Service Verification Letter',
                            'letterType' => 'service_verification'
                        },
                        {
                            'name' => 'Civil Service Preference Letter',
                            'letterType' => 'civil_service'
                        },
                        {
                            'name' => 'Benefit Summary Letter',
                            'letterType' => 'benefit_summary'
                        },
                        {
                            'name' => 'Benefit Verification Letter',
                            'letterType' => 'benefit_verification'
                        }
                    ]
            }
        }
    }
  end

  describe 'GET /mobile/v0/letters' do
    context 'with a valid evss response' do
      it 'matches the letters schema' do
        VCR.use_cassette('evss/letters/letters') do
          get '/mobile/v0/letters', headers: iam_headers
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq(expected_body)
          expect(response.body).to match_json_schema('letters')
        end
      end
    end

    unauthorized_five_hundred = { cassette_name: 'evss/letters/unauthorized' }
    context 'with an 500 unauthorized response', vcr: unauthorized_five_hundred do
      it 'returns a bad gateway response' do
        get '/mobile/v0/letters', headers: iam_headers
        expect(response).to have_http_status(:bad_gateway)
        expect(response.body).to match_json_schema('evss_errors')
      end
    end

    context 'with a 403 response' do
      it 'returns a not authorized response' do
        VCR.use_cassette('evss/letters/letters_403') do
          get '/mobile/v0/letters', headers: iam_headers
          expect(response).to have_http_status(:forbidden)
          expect(response.body).to match_json_schema('evss_errors')
        end
      end
    end

    context 'with a generic 500 response' do
      it 'returns a not found response' do
        VCR.use_cassette('evss/letters/letters_500') do
          get '/mobile/v0/letters', headers: iam_headers
          expect(response).to have_http_status(:internal_server_error)
          expect(response.body).to match_json_schema('evss_errors')
        end
      end
    end
  end
end
