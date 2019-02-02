# frozen_string_literal: true

require 'rails_helper'

require 'evss/request_decision'

RSpec.describe 'EVSS Claims management', type: :request do
  include SchemaMatchers
  VALID_HEADERS = {
    'X-VA-SSN' => '111223333',
    'X-VA-First-Name' => 'Test',
    'X-VA-Last-Name' => 'Consumer',
    'X-VA-EDIPI' => '12345',
    'X-VA-Birth-Date' => '11-11-1111',
    'X-Consumer-Username' => 'TestConsumer'
  }.freeze

  it 'lists all Claims', run_at: 'Tue, 12 Dec 2017 03:09:06 GMT' do
    verifier_stub = instance_double('EVSS::PowerOfAttorneyVerifier')
    allow(EVSS::PowerOfAttorneyVerifier).to receive(:new) { verifier_stub }
    allow(verifier_stub).to receive(:verify)
    VCR.use_cassette('evss/claims/claims') do
      get '/services/claims/v0/claims', nil,
          'X-VA-SSN' => '796043735',
          'X-VA-First-Name' => 'WESLEY',
          'X-VA-Last-Name' => 'FORD',
          'X-VA-EDIPI' => '1007697216',
          'X-Consumer-Username' => 'TestConsumer',
          'X-VA-User' => 'adhoc.test.user',
          'X-VA-Birth-Date' => '1986-05-06T00:00:00+00:00'
      expect(response).to match_response_schema('claims_api/claims')
    end
  end

  context 'for a single claim' do
    it 'shows a single Claim', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
      VCR.use_cassette('evss/claims/claim') do
        get '/services/claims/v0/claims/600118851', nil,
            'X-VA-SSN' => '796043735',
            'X-VA-First-Name' => 'WESLEY',
            'X-VA-Last-Name' => 'FORD',
            'X-VA-EDIPI' => '1007697216',
            'X-Consumer-Username' => 'TestConsumer',
            'X-VA-User' => 'adhoc.test.user',
            'X-VA-Birth-Date' => '1986-05-06T00:00:00+00:00'
        expect(response).to match_response_schema('claims_api/claim')
      end
    end
  end

  context 'header validations' do
    VALID_HEADERS.each_key do |header|
      context "without #{header}" do
        it 'returns a bad request response' do
          VCR.use_cassette('evss/claims/claims') do
            get '/services/claims/v0/claims', nil, VALID_HEADERS.except(header)
            expect(response).to have_http_status(:bad_request)
          end
        end
      end
    end
  end
end
