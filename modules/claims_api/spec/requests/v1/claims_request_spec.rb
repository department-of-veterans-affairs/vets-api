# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BGS Claims management', type: :request do
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
      ClaimsApi::LocalBGS
    else
      ClaimsApi::UnsynchronizedEVSSClaimService
    end
  end
  let(:bgs_claim_id) { '600118851' }

  before do
    stub_poa_verification
    stub_mpi
  end

  context 'index' do
    it 'lists all Claims', run_at: 'Tue, 12 Dec 2017 03:09:06 GMT' do
      with_okta_user(scopes) do |auth_header|
        VCR.use_cassette('bgs/claims/claims') do
          allow_any_instance_of(ClaimsApi::V1::ApplicationController)
            .to receive(:target_veteran).and_return(target_veteran)
          get '/services/claims/v1/claims', params: nil, headers: request_headers.merge(auth_header)
          expect(response).to match_response_schema('claims_api/claims')
        end
      end
    end

    it 'lists all Claims when camel-inflection', run_at: 'Tue, 12 Dec 2017 03:09:06 GMT' do
      with_okta_user(scopes) do |auth_header|
        VCR.use_cassette('bgs/claims/claims') do
          allow_any_instance_of(ClaimsApi::V1::ApplicationController)
            .to receive(:target_veteran).and_return(target_veteran)
          get '/services/claims/v1/claims', params: nil, headers: request_headers_camel.merge(auth_header)
          expect(response).to match_camelized_response_schema('claims_api/claims')
        end
      end
    end

    context 'with errors' do
      it 'shows a errored Claims not found error message' do
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('bgs/claims/claims_with_errors') do
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
        VCR.use_cassette('bgs/claims/claim') do
          get "/services/claims/v1/claims/#{bgs_claim_id}", params: nil, headers: request_headers.merge(auth_header)
          expect(response).to match_response_schema('claims_api/claim')
        end
      end
    end

    it 'shows a single Claim when camel-inflected', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
      with_okta_user(scopes) do |auth_header|
        VCR.use_cassette('bgs/claims/claim') do
          get "/services/claims/v1/claims/#{bgs_claim_id}", params: nil,
                                                            headers: request_headers_camel.merge(auth_header)
          expect(response).to match_camelized_response_schema('claims_api/claim')
        end
      end
    end

    context 'when source matches' do
      context 'when evss_id is provided' do
        it 'shows a single Claim through auto established claims', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
          with_okta_user(scopes) do |auth_header|
            create(:auto_established_claim,
                   source: 'abraham lincoln',
                   auth_headers: { some: 'data' },
                   evss_id: 600_118_851,
                   id: 'd5536c5c-0465-4038-a368-1a9d9daf65c9')
            VCR.use_cassette('bgs/claims/claim') do
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
          with_okta_user(scopes) do |auth_header|
            create(:auto_established_claim,
                   source: 'abraham lincoln',
                   auth_headers: { some: 'data' },
                   evss_id: 600_118_851,
                   id: 'd5536c5c-0465-4038-a368-1a9d9daf65c9')
            VCR.use_cassette('bgs/claims/claim') do
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
          with_okta_user(scopes) do |auth_header|
            create(:auto_established_claim,
                   source: 'abraham lincoln',
                   auth_headers: { some: 'data' },
                   evss_id: 600_118_851,
                   id: 'd5536c5c-0465-4038-a368-1a9d9daf65c9')
            VCR.use_cassette('bgs/claims/claim') do
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
        with_okta_user(scopes) do |auth_header|
          create(:auto_established_claim,
                 source: 'oddball',
                 auth_headers: { some: 'data' },
                 evss_id: 600_118_851,
                 id: 'd5536c5c-0465-4038-a368-1a9d9daf65c9')
          expect_any_instance_of(claims_service).to receive(:update_from_remote)
            .and_raise(StandardError.new('no claim found'))
          VCR.use_cassette('bgs/claims/claim') do
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
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('bgs/claims/claim_with_errors') do
            get '/services/claims/v1/claims/123123131', params: nil, headers: request_headers.merge(auth_header)
            expect(response.status).to eq(404)
          end
        end
      end

      it 'missing MPI Record' do
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('bgs/claims/claim_with_errors') do
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

            expect(response.status).to eq(422)
            body = JSON.parse(response.body)
            expect(body['errors'][0]['detail']).to eq('Unable to locate Veteran in Master Person Index (MPI). ' \
                                                      'Please submit an issue at ask.va.gov or call ' \
                                                      '1-800-MyVA411 (800-698-2411) for assistance.')
          end
        end
      end

      it 'missing an ICN' do
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('bgs/claims/claim_with_errors') do
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

            expect(response.status).to eq(422)
            body = JSON.parse(response.body)
            expect(body['errors'][0]['detail']).to eq('Veteran missing Integration Control Number (ICN). ' \
                                                      'Please submit an issue at ask.va.gov or call 1-800-MyVA411 ' \
                                                      '(800-698-2411) for assistance.')
          end
        end
      end

      it 'shows a single errored Claim with an error message', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
        with_okta_user(scopes) do |auth_header|
          create(:auto_established_claim,
                 source: 'abraham lincoln',
                 auth_headers: auth_header,
                 evss_id: 600_118_851,
                 id: 'd5536c5c-0465-4038-a368-1a9d9daf65c9',
                 status: 'errored',
                 evss_response: [{ 'key' => 'Error', 'severity' => 'FATAL', 'text' => 'Failed' }])
          VCR.use_cassette('bgs/claims/claim') do
            headers = request_headers.merge(auth_header)
            get('/services/claims/v1/claims/d5536c5c-0465-4038-a368-1a9d9daf65c9', params: nil, headers:)
            expect(response.status).to eq(422)
          end
        end
      end

      it 'shows a single errored Claim without an error message', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
        with_okta_user(scopes) do |auth_header|
          create(:auto_established_claim,
                 source: 'abraham lincoln',
                 auth_headers: auth_header,
                 evss_id: 600_118_851,
                 id: 'd5536c5c-0465-4038-a368-1a9d9daf65c9',
                 status: 'errored',
                 evss_response: nil)
          VCR.use_cassette('bgs/claims/claim') do
            headers = request_headers.merge(auth_header)
            get('/services/claims/v1/claims/d5536c5c-0465-4038-a368-1a9d9daf65c9', params: nil, headers:)
            expect(response.status).to eq(422)
          end
        end
      end
    end
  end

  context 'POA verifier' do
    it 'users the poa verifier when the header is present' do
      with_okta_user(scopes) do |auth_header|
        VCR.use_cassette('bgs/claims/claim') do
          verifier_stub = instance_double('BGS::PowerOfAttorneyVerifier')
          allow(BGS::PowerOfAttorneyVerifier).to receive(:new) { verifier_stub }
          allow(verifier_stub).to receive(:verify)
          headers = request_headers.merge(auth_header)
          get("/services/claims/v1/claims/#{bgs_claim_id}", params: nil, headers:)
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
        VCR.use_cassette('bgs/claims/claims') do
          allow_any_instance_of(ClaimsApi::V1::ApplicationController)
            .to receive(:target_veteran).and_return(target_veteran)
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
        VCR.use_cassette('bgs/claims/claims') do
          get '/services/claims/v1/claims', params: nil, headers: auth_header.merge(camel_inflection_header)
          expect(response).to match_camelized_response_schema('claims_api/claims')
        end
      end
    end
  end

  context "when a 'Token Validation Error' is received" do
    it "raises a 'Common::Exceptions::Unauthorized' exception", run_at: 'Tue, 12 Dec 2017 03:09:06 GMT' do
      expect_any_instance_of(Token).to receive(:initialize).and_raise(
        Common::Exceptions::TokenValidationError.new(detail: 'Some Error')
      )

      with_okta_user(scopes) do |auth_header|
        VCR.use_cassette('bgs/claims/claims') do
          get '/services/claims/v1/claims', params: nil, headers: request_headers.merge(auth_header)
          parsed_response = JSON.parse(response.body)

          expect(response.status).to eq(401)
          expect(parsed_response['errors'].first['title']).to eq('Not authorized')
        end
      end
    end
  end

  context 'events timeline' do
    it 'maps BGS data to match previous logic with EVSS data' do
      with_okta_user(scopes) do |auth_header|
        VCR.use_cassette('bgs/claims/claim') do
          get "/services/claims/v1/claims/#{bgs_claim_id}", params: nil, headers: request_headers.merge(auth_header)
          body = JSON.parse(response.body)
          events_timeline = body['data']['attributes']['events_timeline']
          expect(response.status).to eq(200)
          expect(events_timeline[1]['type']).to eq('completed')
          expect(events_timeline[2]['type']).to eq('filed')
        end
      end
    end
  end
end
