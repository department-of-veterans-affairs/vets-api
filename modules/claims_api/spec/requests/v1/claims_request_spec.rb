# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'EVSS Claims management', type: :request do
  include SchemaMatchers

  let(:request_headers) do
    {
      'X-VA-SSN' => '796-04-3735',
      'X-VA-First-Name' => 'WESLEY',
      'X-VA-Last-Name' => 'FORD',
      'X-VA-Birth-Date' => '1986-05-06T00:00:00+00:00'
    }
  end
  let(:camel_inflection_header) { { 'X-Key-Inflection' => 'camel' } }
  let(:request_headers_camel) { request_headers.merge(camel_inflection_header) }
  let(:scopes) { %w[claim.read] }

  before do
    stub_poa_verification
    stub_mvi
  end

  context 'index' do
    it 'lists all Claims', run_at: 'Tue, 12 Dec 2017 03:09:06 GMT' do
      with_okta_user(scopes) do |auth_header|
        VCR.use_cassette('evss/claims/claims') do
          get '/services/claims/v1/claims', params: nil, headers: request_headers.merge(auth_header)
          expect(response).to match_response_schema('claims_api/claims')
        end
      end
    end

    it 'lists all Claims when camel-inflection', run_at: 'Tue, 12 Dec 2017 03:09:06 GMT' do
      with_okta_user(scopes) do |auth_header|
        VCR.use_cassette('evss/claims/claims') do
          get '/services/claims/v1/claims', params: nil, headers: request_headers_camel.merge(auth_header)
          expect(response).to match_camelized_response_schema('claims_api/claims')
        end
      end
    end

    context 'with errors' do
      it 'shows a errored Claims not found error message' do
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('evss/claims/claims_with_errors') do
            get '/services/claims/v1/claims', params: nil, headers: request_headers.merge(auth_header)
            expect(response.status).to eq(404)
          end
        end
      end
    end
  end

  context 'for a single claim' do
    it 'shows a single Claim', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
      with_okta_user(scopes) do |auth_header|
        VCR.use_cassette('evss/claims/claim') do
          get '/services/claims/v1/claims/600118851', params: nil, headers: request_headers.merge(auth_header)
          expect(response).to match_response_schema('claims_api/claim')
        end
      end
    end

    it 'shows a single Claim when camel-inflected', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
      with_okta_user(scopes) do |auth_header|
        VCR.use_cassette('evss/claims/claim') do
          get '/services/claims/v1/claims/600118851', params: nil, headers: request_headers_camel.merge(auth_header)
          expect(response).to match_camelized_response_schema('claims_api/claim')
        end
      end
    end

    it 'shows a single Claim through auto established claims', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
      with_okta_user(scopes) do |auth_header|
        create(:auto_established_claim,
               auth_headers: { some: 'data' },
               evss_id: 600_118_851,
               id: 'd5536c5c-0465-4038-a368-1a9d9daf65c9')
        VCR.use_cassette('evss/claims/claim') do
          get(
            '/services/claims/v1/claims/d5536c5c-0465-4038-a368-1a9d9daf65c9',
            params: nil, headers: request_headers.merge(auth_header)
          )
          expect(response).to match_response_schema('claims_api/claim')
        end
      end
    end

    it 'shows a single Claim through auto established claims when camel-inflected',
       run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
      with_okta_user(scopes) do |auth_header|
        create(:auto_established_claim,
               auth_headers: { some: 'data' },
               evss_id: 600_118_851,
               id: 'd5536c5c-0465-4038-a368-1a9d9daf65c9')
        VCR.use_cassette('evss/claims/claim') do
          get(
            '/services/claims/v1/claims/d5536c5c-0465-4038-a368-1a9d9daf65c9',
            params: nil, headers: request_headers_camel.merge(auth_header)
          )
          expect(response).to match_camelized_response_schema('claims_api/claim')
        end
      end
    end

    context 'with errors' do
      it '404s' do
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('evss/claims/claim_with_errors') do
            get '/services/claims/v1/claims/123123131', params: nil, headers: request_headers.merge(auth_header)
            expect(response.status).to eq(404)
          end
        end
      end

      it 'shows a single errored Claim with an error message', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
        with_okta_user(scopes) do |auth_header|
          create(:auto_established_claim,
                 auth_headers: auth_header,
                 evss_id: 600_118_851,
                 id: 'd5536c5c-0465-4038-a368-1a9d9daf65c9',
                 status: 'errored',
                 evss_response: { 'messages' => [{ 'key' => 'Error', 'severity' => 'FATAL', 'text' => 'Failed' }] })
          VCR.use_cassette('evss/claims/claim') do
            get(
              '/services/claims/v0/claims/d5536c5c-0465-4038-a368-1a9d9daf65c9',
              params: nil,
              headers: {
                'X-VA-SSN' => '796-04-3735', 'X-VA-First-Name' => 'WESLEY',
                'X-VA-Last-Name' => 'FORD', 'X-VA-EDIPI' => '1007697216',
                'X-Consumer-Username' => 'TestConsumer', 'X-VA-User' => 'adhoc.test.user',
                'X-VA-Birth-Date' => '1986-05-06T00:00:00+00:00', 'X-VA-LOA' => '3'
              }
            )
            expect(response.status).to eq(422)
          end
        end
      end

      it 'shows a single errored Claim without an error message', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
        with_okta_user(scopes) do |auth_header|
          create(:auto_established_claim,
                 auth_headers: auth_header,
                 evss_id: 600_118_851,
                 id: 'd5536c5c-0465-4038-a368-1a9d9daf65c9',
                 status: 'errored',
                 evss_response: nil)
          VCR.use_cassette('evss/claims/claim') do
            get(
              '/services/claims/v0/claims/d5536c5c-0465-4038-a368-1a9d9daf65c9',
              params: nil,
              headers: {
                'X-VA-SSN' => '796-04-3735', 'X-VA-First-Name' => 'WESLEY',
                'X-VA-Last-Name' => 'FORD', 'X-VA-EDIPI' => '1007697216',
                'X-Consumer-Username' => 'TestConsumer', 'X-VA-User' => 'adhoc.test.user',
                'X-VA-Birth-Date' => '1986-05-06T00:00:00+00:00', 'X-VA-LOA' => '3'
              }
            )
            expect(response.status).to eq(422)
          end
        end
      end
    end
  end

  context 'POA verifier' do
    it 'users the poa verifier when the header is present' do
      with_okta_user(scopes) do |auth_header|
        VCR.use_cassette('evss/claims/claim') do
          verifier_stub = instance_double('BGS::PowerOfAttorneyVerifier')
          allow(BGS::PowerOfAttorneyVerifier).to receive(:new) { verifier_stub }
          allow(verifier_stub).to receive(:verify)
          headers = request_headers.merge(auth_header)
          get '/services/claims/v1/claims/d5536c5c-0465-4038-a368-1a9d9daf65c9', params: nil, headers: headers
          expect(response.status).to eq(200)
        end
      end
    end
  end

  context 'with oauth user and no headers' do
    it 'lists all Claims', run_at: 'Tue, 12 Dec 2017 03:09:06 GMT' do
      with_okta_user(scopes) do |auth_header|
        verifier_stub = instance_double('BGS::PowerOfAttorneyVerifier')
        allow(BGS::PowerOfAttorneyVerifier).to receive(:new) { verifier_stub }
        allow(verifier_stub).to receive(:verify)
        VCR.use_cassette('evss/claims/claims') do
          get '/services/claims/v1/claims', params: nil, headers: auth_header
          expect(response).to match_response_schema('claims_api/claims')
        end
      end
    end

    it 'lists all Claims when camel-inflected', run_at: 'Tue, 12 Dec 2017 03:09:06 GMT' do
      with_okta_user(scopes) do |auth_header|
        verifier_stub = instance_double('BGS::PowerOfAttorneyVerifier')
        allow(BGS::PowerOfAttorneyVerifier).to receive(:new) { verifier_stub }
        allow(verifier_stub).to receive(:verify)
        VCR.use_cassette('evss/claims/claims') do
          get '/services/claims/v1/claims', params: nil, headers: auth_header.merge(camel_inflection_header)
          expect(response).to match_camelized_response_schema('claims_api/claims')
        end
      end
    end
  end
end
