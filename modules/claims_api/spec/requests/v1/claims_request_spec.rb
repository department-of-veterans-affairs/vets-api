# frozen_string_literal: true

require 'rails_helper'

require 'evss/request_decision'

RSpec.describe 'EVSS Claims management', type: :request do
  include SchemaMatchers
  VALID_HEADERS = {
    'X-VA-SSN' => '111223333',
    'X-VA-First-Name' => 'Test',
    'X-VA-Last-Name' => 'Consumer',
    'X-VA-Birth-Date' => '11-11-1111',
    'X-Consumer-Username' => 'TestConsumer'
  }.freeze

  let(:request_headers) do
    {
      'X-VA-SSN' => '796043735',
      'X-VA-First-Name' => 'WESLEY',
      'X-VA-Last-Name' => 'FORD',
      'X-VA-EDIPI' => '1007697216',
      'X-Consumer-Username' => 'TestConsumer',
      'X-VA-User' => 'adhoc.test.user',
      'X-VA-Birth-Date' => '1986-05-06T00:00:00+00:00'
    }
  end
  let(:scopes) { %w[claim.read] }

  before(:each) do
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
    context 'with errors' do
      it 'renders an empty array' do
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('evss/claims/claims_with_errors') do
            get '/services/claims/v1/claims', params: nil, headers: request_headers.merge(auth_header)
            expect(JSON.parse(response.body)['data'].length).to eq(0)
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
    context 'with errors' do
      it '404s' do
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('evss/claims/claim_with_errors') do
            get '/services/claims/v1/claims/123123131', params: nil, headers: request_headers.merge(auth_header)
            expect(response.status).to eq(404)
          end
        end
      end
    end
  end

  context 'POA verifier' do
    it 'users the poa verifier when the header is present' do
      with_okta_user(scopes) do |auth_header|
        VCR.use_cassette('evss/claims/claim') do
          verifier_stub = instance_double('EVSS::PowerOfAttorneyVerifier')
          allow(EVSS::PowerOfAttorneyVerifier).to receive(:new) { verifier_stub }
          allow(verifier_stub).to receive(:verify)
          headers = request_headers.merge(auth_header)
          get '/services/claims/v1/claims/d5536c5c-0465-4038-a368-1a9d9daf65c9', params: nil, headers: headers
          expect(response.status).to eq(200)
        end
      end
    end
  end

  context 'with oauth user and no headers' do
    it 'lists all Claims ', run_at: 'Tue, 12 Dec 2017 03:09:06 GMT' do
      with_okta_user(scopes) do |auth_header|
        verifier_stub = instance_double('EVSS::PowerOfAttorneyVerifier')
        allow(EVSS::PowerOfAttorneyVerifier).to receive(:new) { verifier_stub }
        allow(verifier_stub).to receive(:verify)
        VCR.use_cassette('evss/claims/claims') do
          get '/services/claims/v1/claims', params: nil, headers: auth_header
          expect(response).to match_response_schema('claims_api/claims')
        end
      end
    end
  end
end
