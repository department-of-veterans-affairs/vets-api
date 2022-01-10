# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'EVSS Claims management', type: :request do
  include SchemaMatchers

  before do
    stub_mpi
  end

  let(:request_headers) do
    { 'X-VA-SSN' => '796-04-3735',
      'X-VA-First-Name' => 'WESLEY',
      'X-VA-Last-Name' => 'FORD',
      'X-Consumer-Username' => 'TestConsumer',
      'X-VA-LOA' => '3',
      'X-VA-Birth-Date' => '1986-05-06T00:00:00+00:00' }
  end
  let(:camel_inflection_header) { { 'X-Key-Inflection' => 'camel' } }
  let(:request_headers_camel) { request_headers.merge(camel_inflection_header) }

  context 'index' do
    it 'lists all Claims', run_at: 'Tue, 12 Dec 2017 03:09:06 GMT' do
      VCR.use_cassette('evss/claims/claims') do
        get '/services/claims/v0/claims',
            params: nil,
            headers: request_headers
        expect(response).to match_response_schema('claims_api/claims')
      end
    end

    it 'lists all Claims when camel-inflected', run_at: 'Tue, 12 Dec 2017 03:09:06 GMT' do
      VCR.use_cassette('evss/claims/claims') do
        get '/services/claims/v0/claims',
            params: nil,
            headers: request_headers_camel
        expect(response).to match_camelized_response_schema('claims_api/claims')
      end
    end

    context 'with errors' do
      it 'shows a errored Claims not found error message' do
        VCR.use_cassette('evss/claims/claims_with_errors') do
          get '/services/claims/v0/claims', params: nil, headers: request_headers
          expect(response.status).to eq(404)
        end
      end

      it 'shows a single errored Claim with an error message', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
        create(:auto_established_claim,
               auth_headers: { some: 'data' },
               source: 'TestConsumer',
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
              'X-VA-Last-Name' => 'FORD',
              'X-Consumer-Username' => 'TestConsumer',
              'X-VA-Birth-Date' => '1986-05-06T00:00:00+00:00', 'X-VA-LOA' => '3'
            }
          )
          expect(response.status).to eq(422)
        end
      end

      it 'shows a single errored Claim without an error message', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
        create(:auto_established_claim,
               source: 'TestConsumer',
               auth_headers: { some: 'data' },
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
              'X-VA-Last-Name' => 'FORD',
              'X-Consumer-Username' => 'TestConsumer',
              'X-VA-Birth-Date' => '1986-05-06T00:00:00+00:00', 'X-VA-LOA' => '3'
            }
          )
          expect(response.status).to eq(422)
        end
      end
    end
  end

  context 'for a single claim' do
    it 'shows a single Claim', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
      VCR.use_cassette('evss/claims/claim') do
        get '/services/claims/v0/claims/600118851',
            params: nil,
            headers: request_headers
        expect(response).to match_response_schema('claims_api/claim')
      end
    end

    it 'shows a single Claim when camel-inflected', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
      VCR.use_cassette('evss/claims/claim') do
        get '/services/claims/v0/claims/600118851',
            params: nil,
            headers: request_headers_camel
        expect(response).to match_camelized_response_schema('claims_api/claim')
      end
    end

    context 'with an auto established claim' do
      let(:evss_claim_id) { 600_118_851 }
      let(:auto_established_claim_id) { 'd5536c5c-0465-4038-a368-1a9d9daf65c9' }
      let(:wesley_ford_headers) do
        {
          'X-VA-SSN' => '796-04-3735', 'X-VA-First-Name' => 'WESLEY',
          'X-VA-Last-Name' => 'FORD',
          'X-Consumer-Username' => 'TestConsumer',
          'X-VA-Birth-Date' => '1986-05-06T00:00:00+00:00', 'X-VA-LOA' => '3'
        }
      end

      before do
        create(:auto_established_claim,
               source: 'TestConsumer',
               auth_headers: { some: 'data' },
               evss_id: evss_claim_id,
               id: auto_established_claim_id)
      end

      it 'shows a single Claim through it', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
        VCR.use_cassette('evss/claims/claim') do
          get(
            "/services/claims/v0/claims/#{evss_claim_id}",
            params: nil,
            headers: wesley_ford_headers
          )
          expect(response).to match_response_schema('claims_api/claim')
        end
      end

      it 'shows a single Claim through it when camel-inflected', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
        VCR.use_cassette('evss/claims/claim') do
          get(
            "/services/claims/v0/claims/#{evss_claim_id}",
            params: nil,
            headers: wesley_ford_headers.merge(camel_inflection_header)
          )
          expect(response).to match_camelized_response_schema('claims_api/claim')
        end
      end
    end

    context 'with errors' do
      it '404s' do
        VCR.use_cassette('evss/claims/claim_with_errors') do
          get '/services/claims/v0/claims/123123131', params: nil, headers: request_headers
          expect(response.status).to eq(404)
        end
      end
    end
  end

  context 'POA verifier' do
    it 'users the poa verifier when the header is present' do
      VCR.use_cassette('evss/claims/claim') do
        get(
          '/services/claims/v0/claims/d5536c5c-0465-4038-a368-1a9d9daf65c9',
          params: nil,
          headers: {
            'X-VA-SSN' => '796-04-3735', 'X-VA-First-Name' => 'WESLEY',
            'X-VA-Last-Name' => 'FORD',
            'X-Consumer-Username' => 'TestConsumer',
            'X-VA-Birth-Date' => '1986-05-06T00:00:00+00:00', 'X-Consumer-POA' => 'A1Q'
          }
        )
      end
    end
  end

  context 'header validations' do
    valid_headers = {
      'X-VA-SSN' => '111-22-3333',
      'X-VA-First-Name' => 'Test',
      'X-VA-Last-Name' => 'Consumer',
      'X-VA-Birth-Date' => '11-11-1111',
      'X-Consumer-Username' => 'test',
      'X-VA-LOA' => '3'
    }

    valid_headers.each_key do |header|
      context "without #{header}" do
        it 'returns a bad request response' do
          VCR.use_cassette('evss/claims/claims') do
            get '/services/claims/v0/claims', params: nil, headers: valid_headers.except(header)
            expect(response).to have_http_status(:bad_request)
          end
        end
      end
    end

    it 'returns error if loa is not 3' do
      VCR.use_cassette('evss/claims/claims') do
        get '/services/claims/v0/claims', params: nil, headers: valid_headers.merge('X-VA-LOA' => 2)
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
