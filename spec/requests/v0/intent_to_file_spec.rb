# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/factories/api_provider_factory'

RSpec.describe 'V0::IntentToFile', type: :request do
  include SchemaMatchers

  let(:user) { build(:disabilities_compensation_user) }
  let(:camel_inflection_header) { { 'X-Key-Inflection' => 'camel' } }
  let(:headers) { { 'CONTENT_TYPE' => 'application/json' } }
  let(:headers_with_camel) { headers.merge('X-Key-Inflection' => 'camel') }

  before do
    sign_in
    Flipper.disable(:disability_compensation_production_tester)
  end

  describe 'GET /v0/intent_to_file' do
    context 'Lighthouse api provider' do
      before do
        allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('test_token')
      end

      context 'with a valid Lighthouse response' do
        it 'matches the intent to files schema' do
          VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/200_response') do
            get '/v0/intent_to_file'
            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('intent_to_files')
          end
        end

        it 'matches the intent to files schema when camel-inflected' do
          VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/200_response') do
            get '/v0/intent_to_file', headers: camel_inflection_header
            expect(response).to have_http_status(:ok)
            expect(response).to match_camelized_response_schema('intent_to_files')
          end
        end

        it 'does not throw a 403 when user is missing birls_id and edipi' do
          # Stub blank birls_id and blank edipi
          allow(user.identity).to receive(:edipi).and_return(nil)
          allow(user).to receive_messages(edipi_mpi: nil, birls_id: nil)
          VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/200_response') do
            get '/v0/intent_to_file'
            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('intent_to_files')
          end
        end
      end

      context 'with a pension ITF type' do
        let(:params) { { itf_type: 'pension' } }

        it 'matches the intent to files schema' do
          VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/200_response_pension') do
            get('/v0/intent_to_file', params:)
            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('intent_to_files')
            expect(JSON.parse(response.body)['data']['attributes']['intent_to_file'][0]['type']).to eq 'pension'
          end
        end
      end

      context 'with a survivor ITF type' do
        let(:params) { { itf_type: 'survivor' } }

        it 'matches the intent to files schema' do
          VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/200_response_survivor') do
            get('/v0/intent_to_file', params:)
            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('intent_to_files')
            expect(JSON.parse(response.body)['data']['attributes']['intent_to_file'][0]['type']).to eq 'survivor'
          end
        end
      end

      context 'error handling tests' do
        [:'404'].each do |status, _error_class|
          error_status = status.to_s.to_i
          cassette_path = "lighthouse/benefits_claims/intent_to_file/#{status}_response"
          it "returns #{status} response" do
            expect(test_error(
                     cassette_path,
                     error_status,
                     headers
                   )).to be(true)
          end

          it "returns a #{status} response with camel-inflection" do
            expect(test_error(
                     cassette_path,
                     error_status,
                     headers_with_camel
                   )).to be(true)
          end
        end

        def test_error(cassette_path, status, headers)
          VCR.use_cassette(cassette_path) do
            get('/v0/intent_to_file', params: nil, headers:)
            expect(response).to have_http_status(status)
            expect(response).to match_response_schema('evss_errors', strict: false)
          end
        end
      end
    end
  end

  describe 'POST /v0/intent_to_file' do
    shared_examples 'create intent to file with specified itf type' do |itf_type|
      before do
        allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('test_token')
      end

      it "matches the #{itf_type} intent to file schema" do
        VCR.use_cassette("lighthouse/benefits_claims/intent_to_file/create_#{itf_type}_200_response") do
          post "/v0/intent_to_file/#{itf_type}"
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('intent_to_file')
        end
      end
    end

    include_examples 'create intent to file with specified itf type', 'pension'
    include_examples 'create intent to file with specified itf type', 'survivor'
  end
end
