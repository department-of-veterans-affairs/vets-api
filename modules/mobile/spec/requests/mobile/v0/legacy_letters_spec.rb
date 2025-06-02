# frozen_string_literal: true

require_relative '../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::Letters', type: :request do
  include JsonSchemaMatchers
  before do
    Flipper.disable(:mobile_lighthouse_letters)
  end

  let!(:user) { sis_user }
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
                    # {
                    #   'name' => 'Proof of Creditable Prescription Drug Coverage Letter',
                    #   'letterType' => 'medicare_partd'
                    # },
                    # {
                    #   'name' => 'Proof of Minimum Essential Coverage Letter',
                    #   'letterType' => 'minimum_essential_coverage'
                    # },
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
                    # {
                    #   'name' => 'Proof of Creditable Prescription Drug Coverage Letter',
                    #   'letterType' => 'medicare_partd'
                    # },
                    # {
                    #   'name' => 'Proof of Minimum Essential Coverage Letter',
                    #   'letterType' => 'minimum_essential_coverage'
                    # },
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

  describe 'GET /mobile/v0/letters' do
    context 'when user does not have access' do
      let!(:user) { sis_user(participant_id: nil) }

      it 'returns forbidden' do
        get '/mobile/v0/letters', headers: sis_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with a valid evss response' do
      context 'when :letters_hide_service_verification_letter is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).and_call_original
          allow(Flipper).to receive(:enabled?).with(:letters_hide_service_verification_letter).and_return(true)
        end

        it 'excludes service_verification and matches the letters schema' do
          VCR.use_cassette('evss/letters/letters') do
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

        it 'does not exclude service_verification and matches the letters schema' do
          VCR.use_cassette('evss/letters/letters') do
            get '/mobile/v0/letters', headers: sis_headers
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)).to eq(letters_body)
            expect(response.body).to match_json_schema('letters')
          end
        end
      end
    end

    unauthorized_five_hundred = { cassette_name: 'evss/letters/unauthorized' }
    context 'with an 500 unauthorized response', vcr: unauthorized_five_hundred do
      it 'returns a bad gateway response' do
        get '/mobile/v0/letters', headers: sis_headers
        expect(response).to have_http_status(:bad_gateway)
        expect(response.body).to match_json_schema('evss_errors')
      end
    end

    context 'with a 403 response' do
      it 'returns a not authorized response' do
        VCR.use_cassette('evss/letters/letters_403') do
          get '/mobile/v0/letters', headers: sis_headers
          expect(response).to have_http_status(:forbidden)
          expect(response.body).to match_json_schema('evss_errors')
        end
      end
    end

    context 'with a generic 500 response' do
      it 'returns a not found response' do
        VCR.use_cassette('evss/letters/letters_500') do
          get '/mobile/v0/letters', headers: sis_headers
          expect(response).to have_http_status(:internal_server_error)
          expect(response.body).to match_json_schema('evss_errors')
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

    context 'with a valid veteran response' do
      it 'matches the letter beneficiary schema' do
        VCR.use_cassette('evss/letters/beneficiary_veteran') do
          get '/mobile/v0/letters/beneficiary', headers: sis_headers
          expect(response).to have_http_status(:ok)
          expect(response.body).to match_json_schema('letter_beneficiary', strict: true)
        end
      end
    end

    context 'with a valid dependent response' do
      it 'does not include those properties' do
        VCR.use_cassette('evss/letters/beneficiary_dependent') do
          get '/mobile/v0/letters/beneficiary', headers: sis_headers
          expect(response).to have_http_status(:ok)
          expect(response.body).to match_json_schema('letter_beneficiary', strict: true)
        end
      end
    end

    context 'with a 403 response' do
      it 'returns a not authorized response' do
        VCR.use_cassette('evss/letters/beneficiary_403') do
          get '/mobile/v0/letters/beneficiary', headers: sis_headers
          expect(response).to have_http_status(:forbidden)
          expect(response.body).to match_json_schema('evss_errors')
        end
      end
    end

    context 'with a 500 response' do
      it 'returns a not found response' do
        VCR.use_cassette('evss/letters/beneficiary_500') do
          get '/mobile/v0/letters/beneficiary', headers: sis_headers
          expect(response).to have_http_status(:internal_server_error)
          expect(response.body).to match_json_schema('evss_errors')
        end
      end
    end
  end

  describe 'POST /mobile/v0/letters/:type/download' do
    context 'when user does not have access' do
      let!(:user) { sis_user(participant_id: nil) }

      it 'returns forbidden' do
        post '/mobile/v0/letters/commissary/download', headers: sis_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with no options' do
      it 'downloads a PDF' do
        VCR.use_cassette('evss/letters/download') do
          post '/mobile/v0/letters/commissary/download', headers: sis_headers
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

      it 'downloads a PDF', :skip_json_api_validation do
        VCR.use_cassette('evss/letters/download_options') do
          post '/mobile/v0/letters/commissary/download', params: options, headers: sis_headers
          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'with a 404 evss response' do
      it 'returns a 404' do
        VCR.use_cassette('evss/letters/download_404') do
          post '/mobile/v0/letters/commissary/download', headers: sis_headers
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'when evss returns lettergenerator.notEligible' do
      it 'raises a 502' do
        VCR.use_cassette('evss/letters/download_not_eligible') do
          post '/mobile/v0/letters/civil_service/download', headers: sis_headers
          expect(response).to have_http_status(:bad_gateway)
        end
      end
    end

    context 'when evss returns Unexpected Error' do
      let(:options) do
        {
          'militaryService' => true,
          'serviceConnectedDisabilities' => false,
          'serviceConnectedEvaluation' => true,
          'nonServiceConnectedPension' => false,
          'monthlyAward' => true,
          'unemployable' => false,
          'specialMonthlyCompensation' => false,
          'adaptedHousing' => false,
          'chapter35Eligibility' => false,
          'deathResultOfDisability' => false,
          'survivorsAward' => false
        }
      end

      it 'returns a 502' do
        VCR.use_cassette('evss/letters/download_unexpected') do
          post '/mobile/v0/letters/benefit_summary/download', params: options, headers: sis_headers
          expect(response).to have_http_status(:bad_gateway)
        end
      end
    end
  end

  describe 'error handling' do
    # EVSS is working on getting users that throw these errors in their CI env
    # until then these VCR cassettes have had their status and bodies
    # manually created and should not be refreshed
    context 'with a letter generator service error' do
      it 'returns a not found response' do
        VCR.use_cassette('evss/letters/letters_letter_generator_service_error') do
          get '/mobile/v0/letters', headers: sis_headers
          expect(response).to have_http_status(:service_unavailable)
          expect(response.body).to match_json_schema('evss_errors')
        end
      end
    end

    context 'with one or more letter destination errors' do
      it 'returns a not found response' do
        VCR.use_cassette('evss/letters/letters_letter_destination_error') do
          get '/mobile/v0/letters', headers: sis_headers
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to match_json_schema('evss_errors')
        end
      end
    end

    context 'with an invalid address error' do
      context 'when the user has not been logged' do
        it 'logs the user edipi' do
          VCR.use_cassette('evss/letters/letters_invalid_address') do
            expect { get '/mobile/v0/letters', headers: sis_headers }.to change(InvalidLetterAddressEdipi, :count).by(1)
            expect(response).to have_http_status(:unprocessable_entity)
          end
        end
      end

      context 'when log record insertion fails' do
        it 'stills return unprocessable_entity' do
          VCR.use_cassette('evss/letters/letters_invalid_address') do
            allow(InvalidLetterAddressEdipi).to receive(:find_or_create_by).and_raise(ActiveRecord::ActiveRecordError)
            expect { get '/mobile/v0/letters', headers: sis_headers }.not_to change(InvalidLetterAddressEdipi, :count)
            expect(response).to have_http_status(:unprocessable_entity)
          end
        end
      end
    end

    context 'with a not eligible error' do
      it 'returns a not found response' do
        VCR.use_cassette('evss/letters/letters_not_eligible_error') do
          get '/mobile/v0/letters', headers: sis_headers
          expect(response).to have_http_status(:bad_gateway)
          expect(response.body).to match_json_schema('evss_errors')
          expect(JSON.parse(response.body)).to have_deep_attributes(
            'errors' => [
              {
                'title' => 'Proxy error',
                'detail' => 'Upstream server returned not eligible response',
                'code' => '111',
                'source' => 'EVSS::Letters::Service',
                'status' => '502',
                'meta' => {
                  'messages' => [
                    {
                      'key' => 'lettergenerator.notEligible',
                      'severity' => 'FATAL',
                      'text' => 'Veteran is not eligible to receive the letter'
                    }
                  ]
                }
              }
            ]
          )
        end
      end
    end

    context 'with can not determine eligibility error' do
      it 'returns a not found response' do
        VCR.use_cassette('evss/letters/letters_determine_eligibility_error') do
          get '/mobile/v0/letters', headers: sis_headers
          expect(response).to have_http_status(:bad_gateway)
          expect(response.body).to match_json_schema('evss_errors')
          expect(JSON.parse(response.body)).to have_deep_attributes(
            'errors' => [
              {
                'title' => 'Proxy error',
                'detail' => 'Can not determine eligibility for potential letters due to upstream server error',
                'code' => '110',
                'source' => 'EVSS::Letters::Service',
                'status' => '502',
                'meta' => {
                  'messages' => [
                    {
                      'key' => 'letterGeneration.letterEligibilityError',
                      'severity' => 'FATAL',
                      'text' => 'Unable to determine eligibility on potential letters'
                    }
                  ]
                }
              }
            ]
          )
        end
      end
    end
  end
end
