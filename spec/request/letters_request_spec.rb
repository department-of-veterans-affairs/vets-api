# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'letters', type: :request do
  include SchemaMatchers

  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:user) { build(:user, :loa3) }

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
    Settings.evss.mock_letters = false
  end

  describe 'GET /v0/letters' do
    context 'with a valid evss response' do
      it 'should match the letters schema' do
        VCR.use_cassette('evss/letters/letters') do
          get '/v0/letters', nil, auth_header
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('letters')
        end
      end
    end

    # TODO(AJD): this use case happens, 500 status but unauthorized message
    # check with evss that they shouldn't be returning 403 instead
    context 'with an 500 unauthorized response' do
      it 'should return a bad gateway response' do
        VCR.use_cassette('evss/letters/unauthorized') do
          get '/v0/letters', nil, auth_header
          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('letters_errors', strict: false)
        end
      end
    end

    context 'with a 403 response' do
      it 'should return a not authorized response' do
        VCR.use_cassette('evss/letters/letters_403') do
          get '/v0/letters', nil, auth_header
          expect(response).to have_http_status(:forbidden)
          expect(response).to match_response_schema('letters_errors', strict: false)
        end
      end
    end

    context 'with a generic 500 response' do
      it 'should return a not found response' do
        VCR.use_cassette('evss/letters/letters_500') do
          get '/v0/letters', nil, auth_header
          expect(response).to have_http_status(:internal_server_error)
          expect(response).to match_response_schema('letters_errors')
        end
      end
    end
  end

  describe 'POST /v0/letters/:id' do
    context 'with no options' do
      it 'should download a PDF' do
        VCR.use_cassette('evss/letters/download') do
          post '/v0/letters/commissary', nil, auth_header
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
      it 'should download a PDF' do
        VCR.use_cassette('evss/letters/download_options') do
          post '/v0/letters/commissary', options, auth_header
          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'with a 404 evss response' do
      let(:user) do
        build(:user, :loa3, first_name: 'John', last_name: 'SMith', birth_date: '1942-02-12', ssn: '7991112233')
      end
      before do
        user.va_profile.edipi = '1005079999'
        user.va_profile.participant_id = '600039999'
      end
      it 'should return a 404' do
        VCR.use_cassette('evss/letters/download_404') do
          post '/v0/letters/commissary', nil, auth_header
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'when evss returns lettergenerator.notEligible' do
      it 'should raise a 502' do
        VCR.use_cassette('evss/letters/download_not_eligible') do
          post '/v0/letters/civil_service', nil, auth_header
          expect(response).to have_http_status(:bad_gateway)
        end
      end
    end

    context 'when evss returns Unexpected Error' do
      let(:user) do
        build(:user, :loa3, first_name: 'Greg', last_name: 'Anderson', birth_date: '1809-02-12', ssn: '796111863')
      end
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
      before do
        user.va_profile.edipi = '1005079124'
        user.va_profile.participant_id = '600036159'
      end
      it 'should return a 502' do
        VCR.use_cassette('evss/letters/download_unexpected') do
          post '/v0/letters/benefit_summary', options, auth_header
          expect(response).to have_http_status(:bad_gateway)
        end
      end
    end
  end

  describe 'GET /v0/letters/beneficiary' do
    context 'with a valid veteran response' do
      it 'should match the letter beneficiary schema' do
        VCR.use_cassette('evss/letters/beneficiary_veteran') do
          get '/v0/letters/beneficiary', nil, auth_header
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('letter_beneficiary')
        end
      end
    end

    context 'with a valid dependent response' do
      it 'should not include those properties' do
        VCR.use_cassette('evss/letters/beneficiary_dependent') do
          get '/v0/letters/beneficiary', nil, auth_header
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('letter_beneficiary')
        end
      end
    end

    context 'with a 403 response' do
      it 'should return a not authorized response' do
        VCR.use_cassette('evss/letters/beneficiary_403') do
          get '/v0/letters/beneficiary', nil, auth_header
          expect(response).to have_http_status(:forbidden)
          expect(response).to match_response_schema('letters_errors', strict: false)
        end
      end
    end

    context 'with a 500 response' do
      it 'should return a not found response' do
        VCR.use_cassette('evss/letters/beneficiary_500') do
          get '/v0/letters/beneficiary', nil, auth_header
          expect(response).to have_http_status(:internal_server_error)
          expect(response).to match_response_schema('letters_errors')
        end
      end
    end
  end

  describe 'error handling' do
    # EVSS is working on getting users that throw these errors in their CI env
    # until then these VCR cassettes have had their status and bodies
    # manually created and should not be refreshed
    context 'with a letter generator service error' do
      it 'should return a not found response' do
        VCR.use_cassette('evss/letters/letters_letter_generator_service_error') do
          get '/v0/letters', nil, auth_header
          expect(response).to have_http_status(:service_unavailable)
          expect(response).to match_response_schema('letters_errors')
        end
      end
    end

    context 'with one or more letter destination errors' do
      it 'should return a not found response' do
        VCR.use_cassette('evss/letters/letters_letter_destination_error') do
          get '/v0/letters', nil, auth_header
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response).to match_response_schema('letters_errors')
        end
      end
    end

    context 'with a not eligible error' do
      it 'should return a not found response' do
        VCR.use_cassette('evss/letters/letters_not_eligible_error') do
          get '/v0/letters', nil, auth_header
          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('letters_errors')
          expect(JSON.load(response.body)).to have_deep_attributes(
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
      it 'should return a not found response' do
        VCR.use_cassette('evss/letters/letters_determine_eligibility_error') do
          get '/v0/letters', nil, auth_header
          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('letters_errors')
          expect(JSON.load(response.body)).to have_deep_attributes(
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

  context 'with an http timeout' do
    before do
      allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
    end

    it 'should return a not found response' do
      get '/v0/letters', nil, auth_header
      expect(response).to have_http_status(:gateway_timeout)
      expect(JSON.load(response.body)).to have_deep_attributes(
        'errors' => [
          {
            'title' => 'Gateway timeout',
            'detail' => 'Did not receive a timely response from an upstream server',
            'code' => '504',
            'status' => '504'
          }
        ]
      )
    end
  end
end
