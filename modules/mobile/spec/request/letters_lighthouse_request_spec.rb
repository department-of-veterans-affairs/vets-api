# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'letters', type: :request do
  include JsonSchemaMatchers

  let(:rsa_key) { OpenSSL::PKey::RSA.generate(2048) }
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

  before do
    skip('Temporary disabling of specs until new LH service available')
    allow(File).to receive(:read).and_return(rsa_key.to_s)
    allow_any_instance_of(IAMUser).to receive(:icn).and_return('24811694708759028')
    user = build(:iam_user)
    iam_sign_in(user)
    Flipper.enable(:mobile_lighthouse_letters, user)
  end

  before(:all) do
    @original_cassette_dir = VCR.configure(&:cassette_library_dir)
    VCR.configure { |c| c.cassette_library_dir = 'modules/mobile/spec/support/vcr_cassettes' }
  end

  after(:all) { VCR.configure { |c| c.cassette_library_dir = @original_cassette_dir } }

  describe 'GET /mobile/v0/letters' do
    context 'with a valid lighthouse response' do
      it 'matches the letters schema' do
        VCR.use_cassette('lighthouse_letters/letters_200', match_requests_on: %i[method uri]) do
          get '/mobile/v0/letters', headers: iam_headers
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq(letters_body)

          # match_json_schema also uses the read method of File objects so we need to revert the stub being done above
          allow(File).to receive(:read).and_call_original
          expect(response.body).to match_json_schema('letters')
        end
      end
    end
  end

  describe 'GET /mobile/v0/letters/beneficiary' do
    context 'with a valid lighthouse response' do
      it 'matches the letters beneficiary schema' do
        VCR.use_cassette('lighthouse_letters/letters_200', match_requests_on: %i[method uri]) do
          get '/mobile/v0/letters/beneficiary', headers: iam_headers
          expect(response).to have_http_status(:ok)
          allow(File).to receive(:read).and_call_original
          expect(response.body).to match_json_schema('letter_beneficiary')
        end
      end
    end
  end

  describe 'Error Handling' do
    context 'with general service error' do
      it 'returns a not found response' do
        VCR.use_cassette('lighthouse_letters/letters_503', match_requests_on: %i[method uri]) do
          get '/mobile/v0/letters', headers: iam_headers
          expect(response).to have_http_status(:service_unavailable)
          expect(response.parsed_body).to eq({ 'errors' =>
                                                 [{ 'title' => 'Service unavailable',
                                                    'detail' => 'Backend Service Outage',
                                                    'code' => '503',
                                                    'status' => '503' }] })
        end
      end
    end

    context 'with upstream service error' do
      it 'returns a not found response' do
        VCR.use_cassette('lighthouse_letters/letters_500_error_bgs', match_requests_on: %i[method uri]) do
          get '/mobile/v0/letters/beneficiary', headers: iam_headers
          expect(response).to have_http_status(:bad_gateway)
          error = response.parsed_body['errors']
          expect(error).to eq([{ 'title' => 'Bad Gateway',
                                 'detail' => 'Received an an invalid response from the upstream server',
                                 'code' => 'MOBL_502_upstream_error',
                                 'status' => '502' }])
        end
      end
    end

    context 'with one or more letter destination errors' do
      it 'returns a not found response' do
        VCR.use_cassette('lighthouse_letters/letters_404', match_requests_on: %i[method uri]) do
          get '/mobile/v0/letters', headers: iam_headers
        end
        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body['errors']).to eq(
          [{ 'title' => 'Record not found',
             'detail' =>
               'The record identified by ICN: 24811694708759028 could not be found',
             'code' => '404',
             'status' => '404' }]
        )
      end
    end
  end
end
