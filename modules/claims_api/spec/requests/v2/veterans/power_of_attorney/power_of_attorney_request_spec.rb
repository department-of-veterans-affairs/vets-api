# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../../rails_helper'
require 'token_validation/v2/client'
require 'bgs_service/local_bgs'

RSpec.describe 'ClaimsApi::V1::PowerOfAttorney::PowerOfAttorneyRequest', type: :request do
  let(:veteran_id) { '1013062086V794840' }
  let(:request_path) { "/services/claims/v2/veterans/#{veteran_id}/power-of-attorney-request" }
  let(:scopes) { %w[system/claim.write system/claim.read] }
  let(:bgs_poa) { { person_org_name: "#{poa_code} name-here" } }
  let(:local_bgs) { ClaimsApi::LocalBGS }

  before do
    FactoryBot.create(:veteran_representative, :vso, representative_id: '999999999999', poa_codes: ['067'])
    FactoryBot.create(:veteran_organization, poa: '067', name: 'DISABLED AMERICAN VETERANS')

    Flipper.disable(:lighthouse_claims_api_poa_dependent_claimants)
  end

  context 'CCG (Client Credentials Grant) flow' do
    context 'when the token is valid' do
      context 'validation and value errors' do
        context 'when the Veteran ICN is not found in MPI' do
          it 'returns a meaningful 404' do
            mock_ccg(scopes) do |auth_header|
              allow_any_instance_of(ClaimsApi::Veteran).to receive(:mpi_record?).and_return(false)

              detail = "Unable to locate Veteran's ID/ICN in Master Person Index (MPI). " \
                       'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.'

              post request_path, params: { data: { attributes: nil } }.to_json, headers: auth_header

              response_body = JSON.parse(response.body)['errors'][0]

              expect(response).to have_http_status(:not_found)
              expect(response_body['title']).to eq('Resource not found')
              expect(response_body['status']).to eq('404')
              expect(response_body['detail']).to eq(detail)
            end
          end
        end

        context 'when the request data is not a valid json object' do
          let(:data) { '123abc' }

          it 'returns a meaningful 422' do
            mock_ccg(scopes) do |auth_header|
              detail = 'The request body is not a valid JSON object: '

              post request_path, params: data, headers: auth_header

              response_body = JSON.parse(response.body)['errors'][0]

              expect(response).to have_http_status(:unprocessable_entity)
              expect(response_body['title']).to eq('Unprocessable entity')
              expect(response_body['status']).to eq('422')
              expect(response_body['detail']).to eq(detail)
            end
          end
        end

        context 'when the Veteran ICN is found in MPI' do
          context 'when the request data does not pass schema validation' do
            let(:request_body) do
              Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                              'power_of_attorney', 'request_representative', 'invalid_schema.json').read
            end

            it 'returns a meaningful 422' do
              VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                mock_ccg(scopes) do |auth_header|
                  detail = 'The property /poa did not contain the required key poaCode'

                  post request_path, params: request_body, headers: auth_header

                  response_body = JSON.parse(response.body)['errors'][0]

                  expect(response).to have_http_status(:unprocessable_entity)
                  expect(response_body['title']).to eq('Unprocessable entity')
                  expect(response_body['status']).to eq('422')
                  expect(response_body['detail']).to eq(detail)
                end
              end
            end
          end

          context 'when the claimant request data does not pass schema validation' do
            let(:request_body) do
              Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                              'power_of_attorney', 'request_representative', 'invalid_claimant_schema.json').read
            end

            it 'returns a meaningful 422' do
              VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                mock_ccg(scopes) do |auth_header|
                  detail = "If claimant is present 'address' must be filled in with required fields addressLine1, " \
                           'city, stateCode, countryCode and zipCode'

                  post request_path, params: request_body, headers: auth_header

                  response_body = JSON.parse(response.body)['errors'][0]

                  expect(response).to have_http_status(:unprocessable_entity)
                  expect(response_body['title']).to eq('Unprocessable Entity')
                  expect(response_body['status']).to eq('422')
                  expect(response_body['detail']).to eq(detail)
                end
              end
            end
          end
        end

        context 'when the request data passes schema validation' do
          context 'when no representative is found with the provided poaCode and registrationNumber' do
            let(:request_body) do
              Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                              'power_of_attorney', 'request_representative', 'invalid_poa.json').read
            end

            it 'returns a meaningful 404' do
              mock_ccg(scopes) do |auth_header|
                detail = 'Could not find an Accredited Representative with registration number: 999999999999 ' \
                         'and poa code: AG3'

                post request_path, params: request_body, headers: auth_header

                response_body = JSON.parse(response.body)['errors'][0]

                expect(response).to have_http_status(:not_found)
                expect(response_body['title']).to eq('Resource not found')
                expect(response_body['status']).to eq('404')
                expect(response_body['detail']).to eq(detail)
              end
            end
          end
        end
      end

      context 'successful request' do
        let(:request_body) do
          Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                          'power_of_attorney', 'request_representative', 'valid.json').read
        end

        context 'lighthouse_claims_v2_poa_requests_skip_bgs enabled' do
          before do
            Flipper.enable(:lighthouse_claims_v2_poa_requests_skip_bgs)
          end

          let(:request_body) do
            Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                            'power_of_attorney', 'request_representative', 'valid_no_claimant.json').read
          end

          it 'does not call the Orchestrator' do
            mock_ccg(scopes) do |auth_header|
              expect_any_instance_of(ClaimsApi::PowerOfAttorneyRequestService::Orchestrator)
                .not_to receive(:submit_request)

              post request_path, params: request_body, headers: auth_header

              response_body = JSON.parse(response.body)

              expect(response).to have_http_status(:created)
              expect(response_body).to eq(JSON.parse(request_body))
            end
          end
        end
      end
    end

    context 'when the token is not valid' do
      it 'returns a 401' do
        post request_path, headers: { 'Authorization' => 'Bearer HelloWorld' }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
