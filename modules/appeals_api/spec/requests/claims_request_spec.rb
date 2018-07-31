# frozen_string_literal: true

require 'rails_helper'

require 'evss/request_decision'

RSpec.describe 'EVSS Claims management', type: :request do
  include SchemaMatchers

  it 'lists all Claims', run_at: 'Tue, 12 Dec 2017 03:09:06 GMT' do
    VCR.use_cassette('evss/claims/claims') do
      get '/services/appeals/v0/claims', nil,
          'X-VA-SSN' => '796043735',
          'X-VA-First-Name' => 'WESLEY',
          'X-VA-Last-Name' => 'FORD',
          'X-VA-EDIPI' => '1007697216',
          'X-Consumer-Username' => 'TestConsumer',
          'X-VA-User' => 'adhoc.test.user',
          'X-VA-Birth-Date' => '1986-05-06T00:00:00+00:00'
      expect(response).to match_response_schema('evss_claims_service')
    end
  end

  context 'for a single claim' do
    it 'shows a single Claim', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
      VCR.use_cassette('evss/claims/claim') do
        get '/services/appeals/v0/claims/600118851', nil,
            'X-VA-SSN' => '796043735',
            'X-VA-First-Name' => 'WESLEY',
            'X-VA-Last-Name' => 'FORD',
            'X-VA-EDIPI' => '1007697216',
            'X-Consumer-Username' => 'TestConsumer',
            'X-VA-User' => 'adhoc.test.user',
            'X-VA-Birth-Date' => '1986-05-06T00:00:00+00:00'
        expect(response).to match_response_schema('evss_claim_service')
      end
    end
  end
end
