# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'
require 'lighthouse/letters_generator/configuration'

RSpec.describe 'letters', type: :request do
  include JsonSchemaMatchers

  let(:letters_body) do
    {
      'data' => {
        'id' => '3097e489-ad75-5746-ab1a-e0aabc1b426a',
        'type' => 'letters',
        'attributes' => {
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
                'name' => 'Benefit Summary and Service Verification Letter',
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
  let(:beneficiary_body) do
    { 'data' =>
       { 'id' => '3097e489-ad75-5746-ab1a-e0aabc1b426a',
         'type' => 'LettersBeneficiaryResponses',
         'attributes' =>
          { 'benefitInformation' =>
             { 'awardEffectiveDate' => '2016-02-04T17:51:56Z',
               'hasChapter35Eligibility' => true,
               'monthlyAwardAmount' => 2673.0,
               'serviceConnectedPercentage' => 2,
               'hasDeathResultOfDisability' => false,
               'hasSurvivorsIndemnityCompensationAward' => false,
               'hasSurvivorsPensionAward' => false,
               'hasAdaptedHousing' => false,
               'hasIndividualUnemployabilityGranted' => false,
               'hasNonServiceConnectedPension' => false,
               'hasServiceConnectedDisabilities' => true,
               'hasSpecialMonthlyCompensation' => false },
            'militaryService' =>
              [{ 'branch' => 'Army', 'characterOfService' => 'HONORABLE',
                 'enteredDate' => '2016-02-04T17:51:56Z', 'releasedDate' => '2016-02-04T17:51:56Z' }] } } }
  end

  before do
    token = 'abcdefghijklmnop'
    allow_any_instance_of(Lighthouse::LettersGenerator::Configuration).to receive(:get_access_token).and_return(token)
    allow_any_instance_of(IAMUser).to receive(:icn).and_return('24811694708759028')
    user = build(:iam_user)
    iam_sign_in(user)
    Flipper.enable(:mobile_lighthouse_letters, user)
  end

  describe 'GET /mobile/v0/letters' do
    context 'with a valid lighthouse response' do
      it 'matches the letters schema' do
        VCR.use_cassette('mobile/lighthouse_letters/letters_200', match_requests_on: %i[method uri]) do
          get '/mobile/v0/letters', headers: iam_headers
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq(letters_body)
          expect(response.body).to match_json_schema('letters')
        end
      end
    end
  end

  describe 'GET /mobile/v0/letters/beneficiary' do
    context 'with a valid lighthouse response' do
      it 'matches the letters beneficiary schema' do
        VCR.use_cassette('mobile/lighthouse_letters/letters_200', match_requests_on: %i[method uri]) do
          get '/mobile/v0/letters/beneficiary', headers: iam_headers
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq(beneficiary_body)
          expect(response.body).to match_json_schema('letter_beneficiary')
        end
      end
    end
  end

  describe 'POST /mobile/v0/letters/:type/download' do
    context 'with no options' do
      it 'downloads a PDF' do
        VCR.use_cassette('mobile/lighthouse_letters/download') do
          post '/mobile/v0/letters/benefit_summary/download', headers: iam_headers
          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'with options' do
      let(:options) do
        {
          'militaryService' => false,
          'serviceConnectedDisabilities' => false,
          'serviceConnectedEvaluation' => false,
          'nonServiceConnectedPension' => false,
          'monthlyAward' => false,
          'unemployable' => false,
          'specialMonthlyCompensation' => false,
          'adaptedHousing' => false,
          'chapter35Eligibility' => false,
          'deathResultOfDisability' => false,
          'survivorsAward' => false
        }
      end

      it 'downloads a PDF' do
        VCR.use_cassette('mobile/lighthouse_letters/download_with_options') do
          post '/mobile/v0/letters/benefit_summary/download', params: options, headers: iam_headers
          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'when an error occurs' do
      it 'raises lighthouse service error' do
        VCR.use_cassette('mobile/lighthouse_letters/download_error') do
          post '/mobile/v0/letters/benefit_summary/download', headers: iam_headers
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end
  end

  describe 'Error Handling' do
    context 'when upstream is unavailable' do
      it 'returns internal service error' do
        VCR.use_cassette('mobile/lighthouse_letters/letters_503', match_requests_on: %i[method uri]) do
          get '/mobile/v0/letters', headers: iam_headers
          expect(response).to have_http_status(:internal_server_error)
          expect(response.parsed_body).to eq({ 'errors' =>
                                                 [{ 'code' => '500',
                                                    'source' => 'Lighthouse::LettersGenerator::Service',
                                                    'status' => '500',
                                                    'meta' => { 'message' => nil } }] })
        end
      end
    end

    context 'with upstream service error' do
      it 'returns a internal server error response' do
        VCR.use_cassette('mobile/lighthouse_letters/letters_500_error_bgs', match_requests_on: %i[method uri]) do
          get '/mobile/v0/letters/beneficiary', headers: iam_headers
          expect(response).to have_http_status(:internal_server_error)
          error = response.parsed_body['errors']
          expect(error).to eq([{ 'title' => 'Required Backend Connection Error',
                                 'detail' => 'Required Backend Connection Error',
                                 'code' => '500',
                                 'source' => 'Lighthouse::LettersGenerator::Service',
                                 'status' => '500',
                                 'meta' => { 'message' => 'Backend Service Error BGS' } }])
        end
      end
    end

    context 'when user is not found' do
      it 'returns a not found response' do
        VCR.use_cassette('mobile/lighthouse_letters/letters_404', match_requests_on: %i[method uri]) do
          get '/mobile/v0/letters', headers: iam_headers
        end
        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body['errors']).to eq(
          [{ 'title' => 'Person for ICN not found',
             'detail' => 'Person for ICN not found',
             'code' => 'LH_not_found',
             'source' => 'Lighthouse::LettersGenerator::Service',
             'status' => '404',
             'meta' => { 'message' => 'No data found for ICN' } }]
        )
      end
    end
  end
end
