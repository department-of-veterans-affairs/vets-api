# frozen_string_literal: true

require_relative '../../../support/helpers/rails_helper'

require 'lighthouse/letters_generator/configuration'

RSpec.describe 'Mobile::V0::Letters', type: :request do
  include JsonSchemaMatchers

  let(:letter_json) do
    {
      'data' =>
        {
          'id' => user.uuid,
          'type' => 'letter',
          'attributes' => {
            'letter' =>
            {
              'letterDescription' => 'This card verifies that you served honorably in the Armed Forces.',
              'letterContent' => [
                { 'contentKey' => 'front-of-card',
                  'contentTitle' => '<front of card>',
                  'content' =>
                  "This card is to serve as proof the individual listed below served honorably in the Uniformed \
Services of the United States. Jesse Gray 1708 Tiburon Blvd Tiburon, CA 94921 Effective as of: June 08, 2023 DoD \
ID Number: 1293307390 Date of Birth: December 15, 1954 Branch Of Service: Army"},
                {
                  'contentKey' => 'back-of-card',
                  'contentTitle' => '<back of card>',
                  'content' =>
                  "United States of America Department of Veterans Affairs General Benefit Information 1-800-827-1000 \
Health Care Information 1-877-222-VETS (8387) This card does not reflect entitlement to any benefits administered by \
the Department of Veterans Affairs or serve as proof of receiving such benefits."
                },
                {
                  'contentKey' => 'contact-us',
                  'contentTitle' => 'How You Can Contact Us',
                  'content' =>
                  "If you need general information about benefits and eligibility, please visit us at \
https://www.va.gov. Call us at 1-800-827-1000. Contact us using Telecommunications Relay Services (TTY) at 711 24/7. \
Send electronic inquiries through the Internet at https://www.va.gov/contact-us."
                }
              ]
            }
          }
        }
    }
  end

  let(:letters_body) do
    {
      'data' => {
        'id' => user.uuid,
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

  let(:no_service_verification_body) do
    {
      'data' => {
        'id' => user.uuid,
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
       { 'id' => user.uuid,
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

  let!(:user) { sis_user(icn: '24811694708759028') }

  before do
    token = 'abcdefghijklmnop'
    allow_any_instance_of(Lighthouse::LettersGenerator::Configuration).to receive(:get_access_token).and_return(token)
    Flipper.enable_actor(:mobile_lighthouse_letters, user)
  end

  describe 'GET /mobile/v0/letters' do
    context 'when user does not have access' do
      let!(:user) { sis_user(participant_id: nil) }

      it 'returns forbidden' do
        get '/mobile/v0/letters', headers: sis_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with a valid lighthouse response' do
      context 'when :letters_hide_service_verification_letter is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).and_call_original
          allow(Flipper).to receive(:enabled?).with(:letters_hide_service_verification_letter).and_return(true)
        end

        it 'excludes the Service Verification letter' do
          VCR.use_cassette('mobile/lighthouse_letters/letters_200', match_requests_on: %i[method uri]) do
            get '/mobile/v0/letters', headers: sis_headers
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)).to eq(no_service_verification_body)
            expect(response.body).to match_json_schema('letters')
          end
        end

        it 'excludes the Service Verification letter and filters unlisted letter types' do
          VCR.use_cassette('mobile/lighthouse_letters/letters_with_extra_types_200',
                           match_requests_on: %i[method uri]) do
            get '/mobile/v0/letters', headers: sis_headers
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)).to eq(no_service_verification_body)
            expect(response.body).to match_json_schema('letters')
          end
        end
      end

      context 'when :letters_hide_service_verification_letter is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).and_call_original
          allow(Flipper).to receive(:enabled?).with(:letters_hide_service_verification_letter).and_return(false)
        end

        it 'does not exclude the Service Verification letter and matches the letters schema' do
          VCR.use_cassette('mobile/lighthouse_letters/letters_200', match_requests_on: %i[method uri]) do
            get '/mobile/v0/letters', headers: sis_headers
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)).to eq(letters_body)
            expect(response.body).to match_json_schema('letters')
          end
        end

        it 'filters unlisted letter types' do
          VCR.use_cassette('mobile/lighthouse_letters/letters_with_extra_types_200',
                           match_requests_on: %i[method uri]) do
            get '/mobile/v0/letters', headers: sis_headers
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)).to eq(letters_body)
            expect(response.body).to match_json_schema('letters')
          end
        end
      end
    end
  end

  describe 'GET /mobile/v0/letters/beneficiary' do
    context 'when user does not have access' do
      let!(:user) { sis_user(participant_id: nil) }

      it 'returns forbidden' do
        get '/mobile/v0/letters/beneficiary', headers: sis_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with a valid lighthouse response' do
      it 'matches the letters beneficiary schema' do
        VCR.use_cassette('mobile/lighthouse_letters/letters_200', match_requests_on: %i[method uri]) do
          get '/mobile/v0/letters/beneficiary', headers: sis_headers
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq(beneficiary_body)
          expect(response.body).to match_json_schema('letter_beneficiary')
        end
      end
    end
  end

  describe 'POST /mobile/v0/letters/:type/download' do
    context 'when user does not have access' do
      let!(:user) { sis_user(participant_id: nil) }

      it 'returns forbidden' do
        post '/mobile/v0/letters/benefit_summary/download', headers: sis_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    describe 'formats' do
      context 'when format is unspecified' do
        it 'downloads a PDF' do
          VCR.use_cassette('mobile/lighthouse_letters/download') do
            post '/mobile/v0/letters/benefit_summary/download', headers: sis_headers
            expect(response).to have_http_status(:ok)
            expect(response.media_type).to eq('application/pdf')
          end
        end
      end

      context 'when format is pdf' do
        it 'downloads a PDF' do
          VCR.use_cassette('mobile/lighthouse_letters/download') do
            post '/mobile/v0/letters/benefit_summary/download', headers: sis_headers, params: { format: 'pdf' },
                                                                as: :json
            expect(response).to have_http_status(:ok)
            expect(response.media_type).to eq('application/pdf')
          end
        end
      end

      context 'when format is json' do
        it 'returns json that matches the letter schema' do
          VCR.use_cassette('mobile/lighthouse_letters/download_as_json', match_requests_on: %i[method uri]) do
            post '/mobile/v0/letters/proof_of_service/download', headers: sis_headers, params: { format: 'json' },
                                                                 as: :json

            expect(response).to have_http_status(:ok)
            expect(response.media_type).to eq('application/json')
            expect(JSON.parse(response.body)).to eq(letter_json)
            expect(response.body).to match_json_schema('letter')
          end
        end
      end

      context 'when format is something else' do
        it 'returns unprocessable entity' do
          VCR.use_cassette('mobile/lighthouse_letters/download') do
            post '/mobile/v0/letters/benefit_summary/download', headers: sis_headers, params: { format: 'floormat' },
                                                                as: :json
            expect(response).to have_http_status(:unprocessable_entity)
          end
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
          post '/mobile/v0/letters/benefit_summary/download', params: options, headers: sis_headers, as: :json
          expect(response).to have_http_status(:ok)
          expect(response.media_type).to eq('application/pdf')
        end
      end

      it 'downloads json' do
        VCR.use_cassette('mobile/lighthouse_letters/download_as_json_with_options',
                         match_requests_on: %i[method uri]) do
          post '/mobile/v0/letters/proof_of_service/download', headers: sis_headers,
                                                               params: options.merge({ format: 'json' }),
                                                               as: :json

          expect(response).to have_http_status(:ok)
          expect(response.media_type).to eq('application/json')
          expect(JSON.parse(response.body)).to eq(letter_json)
          expect(response.body).to match_json_schema('letter')
        end
      end
    end

    context 'when an error occurs' do
      it 'raises lighthouse service error' do
        VCR.use_cassette('mobile/lighthouse_letters/download_error') do
          post '/mobile/v0/letters/benefit_summary/download', headers: sis_headers

          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    context 'with an invalid letter type' do
      it 'returns 400 bad request' do
        post '/mobile/v0/letters/not_real/download', headers: sis_headers

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body['errors'][0]).to include(
          'detail' => 'Letter type of not_real is not one of the expected options',
          'source' => 'Mobile::V0::LettersController',
          'status' => '400'
        )
      end
    end
  end

  describe 'Error Handling' do
    context 'when user is not authorized to use lighthouse' do
      let!(:user) { sis_user(icn: '24811694708759028', participant_id: nil) }

      it 'returns 403 forbidden' do
        get '/mobile/v0/letters', headers: sis_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when upstream is unavailable' do
      it 'returns 503 service unavailable' do
        VCR.use_cassette('mobile/lighthouse_letters/letters_503', match_requests_on: %i[method uri]) do
          get '/mobile/v0/letters', headers: sis_headers
          expect(response).to have_http_status(:service_unavailable)
          expect(response.parsed_body).to eq(
            { 'errors' =>
              [{
                'title' => 'Service unavailable',
                'detail' => 'Backend Service Outage',
                'code' => '503',
                'status' => '503'
              }] }
          )
        end
      end
    end

    context 'with upstream service error' do
      it 'returns a internal server error response' do
        VCR.use_cassette('mobile/lighthouse_letters/letters_500_error_bgs', match_requests_on: %i[method uri]) do
          get '/mobile/v0/letters/beneficiary', headers: sis_headers
          expect(response).to have_http_status(:internal_server_error)
          error = response.parsed_body['errors']
          expect(error[0]).to include(
            'title' => 'Required Backend Connection Error',
            'detail' => 'Backend Service Error BGS',
            'status' => '500'
          )
        end
      end
    end

    context 'when user is not found' do
      it 'returns a not found response' do
        VCR.use_cassette('mobile/lighthouse_letters/letters_404', match_requests_on: %i[method uri]) do
          get '/mobile/v0/letters', headers: sis_headers
        end
        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body['errors'][0]).to include(
          'status' => '404',
          'title' => 'Person for ICN not found'
        )
      end
    end
  end
end
