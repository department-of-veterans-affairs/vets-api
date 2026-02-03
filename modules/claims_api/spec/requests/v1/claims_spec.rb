# frozen_string_literal: true

require 'rails_helper'
require_relative '../../rails_helper'
require 'bgs/power_of_attorney_verifier'
require 'bgs_service/e_benefits_bnft_claim_status_web_service'

RSpec.describe 'ClaimsApi::V1::Claims', type: :request do
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
  let(:target_veteran) do
    OpenStruct.new(
      icn: '1012832025V743496',
      first_name: 'Wesley',
      last_name: 'Ford',
      loa: { current: 3, highest: 3 },
      edipi: '1007697216',
      ssn: '796043735',
      participant_id: '600061742',
      mpi: OpenStruct.new(
        icn: '1012832025V743496',
        profile: OpenStruct.new(ssn: '796043735')
      )
    )
  end
  let(:claims_service) do
    if Flipper.enabled? :claims_status_v1_bgs_enabled
      ClaimsApi::EbenefitsBnftClaimStatusWebService
    else
      ClaimsApi::UnsynchronizedEVSSClaimService
    end
  end
  let(:bgs_claim_id) { '600118851' }

  before do
    stub_poa_verification
  end

  context 'index' do
    it 'lists all Claims', run_at: 'Tue, 12 Dec 2017 03:09:06 GMT' do
      mock_acg(scopes) do |auth_header|
        VCR.use_cassette('claims_api/bgs/claims/claims') do
          allow_any_instance_of(ClaimsApi::V1::ApplicationController)
            .to receive(:target_veteran).and_return(target_veteran)
          get '/services/claims/v1/claims', params: nil, headers: request_headers.merge(auth_header)
          expect(response).to match_response_schema('claims_api/claims')
        end
      end
    end

    it 'lists all Claims when camel-inflection', run_at: 'Tue, 12 Dec 2017 03:09:06 GMT' do
      mock_acg(scopes) do |auth_header|
        VCR.use_cassette('claims_api/bgs/claims/claims') do
          allow_any_instance_of(ClaimsApi::V1::ApplicationController)
            .to receive(:target_veteran).and_return(target_veteran)
          get '/services/claims/v1/claims', params: nil, headers: request_headers_camel.merge(auth_header)
          expect(response).to match_camelized_response_schema('claims_api/claims')
        end
      end
    end

    context 'with errors' do
      it 'shows a errored Claims not found error message' do
        mock_acg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/bgs/claims/claims_with_errors') do
            get '/services/claims/v1/claims', params: nil, headers: request_headers.merge(auth_header)
            expect(response).to have_http_status(:not_found)
          end
        end
      end
    end
  end

  context 'for a single claim' do
    it 'shows a single Claim', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
      mock_acg(scopes) do |auth_header|
        VCR.use_cassette('claims_api/bgs/claims/claim') do
          get "/services/claims/v1/claims/#{bgs_claim_id}", params: nil, headers: request_headers.merge(auth_header)
          expect(response).to match_response_schema('claims_api/claim')
        end
      end
    end

    it 'shows a single Claim when camel-inflected', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
      mock_acg(scopes) do |auth_header|
        VCR.use_cassette('claims_api/bgs/claims/claim') do
          get "/services/claims/v1/claims/#{bgs_claim_id}", params: nil,
                                                            headers: request_headers_camel.merge(auth_header)
          expect(response).to match_camelized_response_schema('claims_api/claim')
        end
      end
    end

    context 'when source matches' do
      context 'when evss_id is provided' do
        it 'shows a single Claim through auto established claims', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
          mock_acg(scopes) do |auth_header|
            create(:auto_established_claim,
                   status: 'pending',
                   source: 'abraham lincoln',
                   auth_headers: { some: 'data' },
                   evss_id: 600_118_851,
                   id: 'd5536c5c-0465-4038-a368-1a9d9daf65c9')
            VCR.use_cassette('claims_api/bgs/claims/claim') do
              get(
                "/services/claims/v1/claims/#{bgs_claim_id}",
                params: nil, headers: request_headers.merge(auth_header)
              )
              expect(response).to match_response_schema('claims_api/claim')
              expect(JSON.parse(response.body)['data']['id']).to eq(bgs_claim_id)
            end
          end
        end

        it 'shows a single Claim through auto established claims when camel-inflected',
           run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
          mock_acg(scopes) do |auth_header|
            create(:auto_established_claim,
                   status: 'pending',
                   source: 'abraham lincoln',
                   auth_headers: { some: 'data' },
                   evss_id: 600_118_851,
                   id: 'd5536c5c-0465-4038-a368-1a9d9daf65c9')
            VCR.use_cassette('claims_api/bgs/claims/claim') do
              get(
                "/services/claims/v1/claims/#{bgs_claim_id}",
                params: nil, headers: request_headers_camel.merge(auth_header)
              )
              expect(response).to match_camelized_response_schema('claims_api/claim')
              expect(JSON.parse(response.body)['data']['id']).to eq(bgs_claim_id)
            end
          end
        end
      end

      context 'when uuid is provided' do
        it 'shows a single Claim through auto established claims', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
          mock_acg(scopes) do |auth_header|
            create(:auto_established_claim,
                   status: 'pending',
                   source: 'abraham lincoln',
                   auth_headers: { some: 'data' },
                   evss_id: 600_118_851,
                   id: 'd5536c5c-0465-4038-a368-1a9d9daf65c9')
            VCR.use_cassette('claims_api/bgs/claims/claim') do
              get(
                '/services/claims/v1/claims/d5536c5c-0465-4038-a368-1a9d9daf65c9',
                params: nil, headers: request_headers.merge(auth_header)
              )
              expect(response).to match_response_schema('claims_api/claim')
              expect(JSON.parse(response.body)['data']['id']).to eq('d5536c5c-0465-4038-a368-1a9d9daf65c9')
            end
          end
        end
      end
    end

    context 'when source does not match' do
      it 'shows a single Claim through auto established claims', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
        mock_acg(scopes) do |auth_header|
          create(:auto_established_claim,
                 status: 'pending',
                 source: 'oddball',
                 auth_headers: { some: 'data' },
                 evss_id: 600_118_851,
                 id: 'd5536c5c-0465-4038-a368-1a9d9daf65c9')
          expect_any_instance_of(claims_service).to receive(:update_from_remote)
            .and_raise(StandardError.new('no claim found'))
          VCR.use_cassette('claims_api/bgs/claims/claim') do
            get(
              "/services/claims/v1/claims/#{bgs_claim_id}",
              params: nil, headers: request_headers.merge(auth_header)
            )
            expect(response.code.to_i).to eq(404)
          end
        end
      end
    end

    context 'with errors' do
      it '404s' do
        mock_acg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/bgs/claims/claim_with_errors') do
            get '/services/claims/v1/claims/123123131', params: nil, headers: request_headers.merge(auth_header)
            expect(response).to have_http_status(:not_found)
          end
        end
      end

      it 'missing MPI Record' do
        mock_acg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/bgs/claims/claim_with_errors') do
            vet = ClaimsApi::Veteran.new(
              uuid: request_headers['X-VA-SSN']&.gsub(/[^0-9]/, ''),
              ssn: request_headers['X-VA-SSN']&.gsub(/[^0-9]/, ''),
              first_name: request_headers['X-VA-First-Name'],
              last_name: request_headers['X-VA-Last-Name'],
              va_profile: ClaimsApi::Veteran.build_profile(request_headers['X-VA-Birth-Date']),
              last_signed_in: Time.now.utc
            )
            vet.participant_id = nil
            allow_any_instance_of(ClaimsApi::V1::ApplicationController)
              .to receive(:veteran_from_headers).and_return(vet)

            allow_any_instance_of(ClaimsApi::Veteran)
              .to receive(:mpi_record?).and_return(false)

            get '/services/claims/v1/claims/123123131', params: nil, headers: request_headers.merge(auth_header)

            expect(response).to have_http_status(:unprocessable_entity)
            body = JSON.parse(response.body)
            expect(body['errors'][0]['detail']).to eq('Unable to locate Veteran in Master Person Index (MPI). ' \
                                                      'Please submit an issue at ask.va.gov or call ' \
                                                      '1-800-MyVA411 (800-698-2411) for assistance.')
          end
        end
      end

      it 'missing an ICN' do
        mock_acg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/bgs/claims/claim_with_errors') do
            vet = ClaimsApi::Veteran.new(
              uuid: request_headers['X-VA-SSN']&.gsub(/[^0-9]/, ''),
              ssn: request_headers['X-VA-SSN']&.gsub(/[^0-9]/, ''),
              first_name: request_headers['X-VA-First-Name'],
              last_name: request_headers['X-VA-Last-Name'],
              va_profile: ClaimsApi::Veteran.build_profile(request_headers['X-VA-Birth-Date']),
              last_signed_in: Time.now.utc
            )
            vet.icn = nil
            allow_any_instance_of(ClaimsApi::V1::ApplicationController)
              .to receive(:veteran_from_headers).and_return(vet)

            get '/services/claims/v1/claims/123123131', params: nil, headers: request_headers.merge(auth_header)

            expect(response).to have_http_status(:unprocessable_entity)
            body = JSON.parse(response.body)
            expect(body['errors'][0]['detail']).to eq('Veteran missing Integration Control Number (ICN). ' \
                                                      'Please submit an issue at ask.va.gov or call 1-800-MyVA411 ' \
                                                      '(800-698-2411) for assistance.')
          end
        end
      end

      it 'shows a single errored Claim with an error message', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
        mock_acg(scopes) do |auth_header|
          create(:auto_established_claim,
                 source: 'abraham lincoln',
                 auth_headers: auth_header,
                 evss_id: 600_118_851,
                 id: 'd5536c5c-0465-4038-a368-1a9d9daf65c9',
                 status: 'errored',
                 evss_response: [{ 'key' => 'Error', 'severity' => 'FATAL', 'text' => 'Failed' }])
          VCR.use_cassette('claims_api/bgs/claims/claim') do
            headers = request_headers.merge(auth_header)
            get('/services/claims/v1/claims/d5536c5c-0465-4038-a368-1a9d9daf65c9', params: nil, headers:)
            expect(response).to have_http_status(:unprocessable_entity)
          end
        end
      end

      it 'shows a single errored Claim without an error message', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
        mock_acg(scopes) do |auth_header|
          create(:auto_established_claim,
                 source: 'abraham lincoln',
                 auth_headers: auth_header,
                 evss_id: 600_118_851,
                 id: 'd5536c5c-0465-4038-a368-1a9d9daf65c9',
                 status: 'errored',
                 evss_response: nil)
          VCR.use_cassette('claims_api/bgs/claims/claim') do
            headers = request_headers.merge(auth_header)
            get('/services/claims/v1/claims/d5536c5c-0465-4038-a368-1a9d9daf65c9', params: nil, headers:)
            expect(response).to have_http_status(:unprocessable_entity)
          end
        end
      end
    end
  end

  context 'POA verifier' do
    it 'users the poa verifier when the header is present' do
      mock_acg(scopes) do |auth_header|
        VCR.use_cassette('claims_api/bgs/claims/claim') do
          verifier_stub = instance_double(BGS::PowerOfAttorneyVerifier)
          allow(BGS::PowerOfAttorneyVerifier).to receive(:new) { verifier_stub }
          allow(verifier_stub).to receive(:verify)
          headers = request_headers.merge(auth_header)
          get("/services/claims/v1/claims/#{bgs_claim_id}", params: nil, headers:)
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end

  context 'with oauth user and no headers' do
    it 'lists all Claims', run_at: 'Tue, 12 Dec 2017 03:09:06 GMT' do
      mock_acg(scopes) do |auth_header|
        verifier_stub = instance_double(BGS::PowerOfAttorneyVerifier)
        allow(BGS::PowerOfAttorneyVerifier).to receive(:new) { verifier_stub }
        allow(verifier_stub).to receive(:verify)
        VCR.use_cassette('claims_api/bgs/claims/claims') do
          allow_any_instance_of(ClaimsApi::V1::ApplicationController)
            .to receive(:target_veteran).and_return(target_veteran)
          get '/services/claims/v1/claims', params: nil, headers: auth_header
          expect(response).to match_response_schema('claims_api/claims')
        end
      end
    end

    it 'lists all Claims when camel-inflected', run_at: 'Tue, 12 Dec 2017 03:09:06 GMT' do
      mock_acg(scopes) do |auth_header|
        verifier_stub = instance_double(BGS::PowerOfAttorneyVerifier)
        allow(BGS::PowerOfAttorneyVerifier).to receive(:new) { verifier_stub }
        allow(verifier_stub).to receive(:verify)
        VCR.use_cassette('claims_api/bgs/claims/claims') do
          get '/services/claims/v1/claims', params: nil, headers: auth_header.merge(camel_inflection_header)
          expect(response).to match_camelized_response_schema('claims_api/claims')
        end
      end
    end
  end

  context "when a 'Token Validation Error' is received" do
    it "raises a 'Common::Exceptions::Unauthorized' exception", run_at: 'Tue, 12 Dec 2017 03:09:06 GMT' do
      auth = { Authorization: 'Bearer The-quick-brown-fox-jumped-over-the-lazy-dog' }
      VCR.use_cassette('claims_api/bgs/claims/claims') do
        get '/services/claims/v1/claims', params: nil,
                                          headers: request_headers.merge(auth)
        parsed_response = JSON.parse(response.body)

        expect(response).to have_http_status(:unauthorized)
        expect(parsed_response['errors'].first['title']).to eq('Not authorized')
      end
    end
  end

  context 'events timeline' do
    it 'maps BGS data to match previous logic with EVSS data' do
      mock_acg(scopes) do |auth_header|
        VCR.use_cassette('claims_api/bgs/claims/claim') do
          get "/services/claims/v1/claims/#{bgs_claim_id}", params: nil, headers: request_headers.merge(auth_header)
          body = JSON.parse(response.body)
          events_timeline = body['data']['attributes']['events_timeline']
          expect(response).to have_http_status(:ok)
          expect(events_timeline[1]['type']).to eq('completed')
          expect(events_timeline[2]['type']).to eq('filed')
        end
      end
    end
  end

  # possible to have errors saved in production that were saved with this wrapper
  # so need to make sure they do not break the formatter, even though the
  # key of 400 will still show as the source, it will return the claim instead of saying 'not found'
  context 'when a claim has an evss_response message with a key that is an integer' do
    let(:err_message) do
      [{
        'key' => 400,
        'severity' => 'FATAL',
        'text' =>
        { 'messages' =>
          [{
            'key' => 'form526.submit.establishClaim.serviceError',
            'severity' => 'FATAL',
            'text' => 'Claim not established. System error with BGS. GUID: 00797c5d-89d4-4da6-aab7-24b4ad0e4a4f'
          }] }
      }]
    end

    it 'shows correct error message despite the key being an integer' do
      mock_acg(scopes) do |auth_header|
        create(:auto_established_claim,
               source: 'abraham lincoln',
               auth_headers: auth_header,
               evss_id: 600_118_851,
               id: 'd5536c5c-0465-4038-a368-1a9d9daf65c9',
               status: 'errored',
               evss_response: err_message)
        VCR.use_cassette('bgs/claims/claim') do
          headers = request_headers.merge(auth_header)
          get('/services/claims/v1/claims/d5536c5c-0465-4038-a368-1a9d9daf65c9', params: nil, headers:)
          expect(response).not_to have_http_status(:not_found)
          body = JSON.parse(response.body)
          expect(body['errors'][0]['detail']).not_to eq('Claim not found')
          expect(body['errors'][0]['source']).to eq('400')
          expect(body['errors'][0]['detail']).to include('Claim not established')
        end
      end
    end
  end
end
