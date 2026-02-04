# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../../rails_helper'
require 'token_validation/v2/client'
require 'bgs_service/local_bgs'

RSpec.describe 'ClaimsApi::V2::PowerOfAttorney::PowerOfAttorneyRequest', type: :request do
  let(:veteran_id) { '1013062086V794840' }
  let(:request_path) { "/services/claims/v2/veterans/#{veteran_id}/power-of-attorney-request" }
  let(:scopes) { %w[system/claim.write system/claim.read] }
  let(:bgs_poa) { { person_org_name: "#{poa_code} name-here" } }
  let(:local_bgs) { ClaimsApi::LocalBGS }

  before do
    create(:veteran_representative, :vso, representative_id: '999999999999', poa_codes: ['067'])
    create(:veteran_organization, poa: '067', name: 'DISABLED AMERICAN VETERANS')
    allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_poa_dependent_claimants).and_return(false)
  end

  context 'CCG (Client Credentials Grant) flow' do
    context 'when the token is valid' do
      context 'validation and value errors' do
        context 'when the Veteran ICN is not found in MPI' do
          it 'returns a meaningful 404' do
            mock_ccg(scopes) do |auth_header|
              allow_any_instance_of(ClaimsApi::V2::Veterans::PowerOfAttorney::RequestController)
                .to receive(:validate_country_code).and_return(nil)
              allow_any_instance_of(ClaimsApi::Veteran).to receive(:mpi_record?).and_return(false)

              detail = "Unable to locate Veteran's ID/ICN in Master Person Index (MPI). " \
                       'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.'

              post request_path, params: { data: { attributes: nil } }.to_json, headers: auth_header

              response_body = JSON.parse(response.body)['errors'][0]

              expect(response).to have_http_status(:not_found)
              expect(response_body['title']).to eq('Resource not found')
              expect(response_body['status']).to eq('404')
              expect(response_body['detail']).to include(detail)
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
              expect(response_body['detail']).to include(detail)
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
                  detail = 'The property /representative did not contain the required key poaCode'

                  post request_path, params: request_body, headers: auth_header

                  response_body = JSON.parse(response.body)['errors'][0]

                  expect(response).to have_http_status(:unprocessable_entity)
                  expect(response_body['title']).to eq('Unprocessable entity')
                  expect(response_body['status']).to eq('422')
                  expect(response_body['detail']).to include(detail)
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
                           "city, stateCode and countryCode. If the countryCode is 'US' then zipCode is also required."

                  post request_path, params: request_body, headers: auth_header

                  response_body = JSON.parse(response.body)['errors'][0]

                  expect(response).to have_http_status(:unprocessable_entity)
                  expect(response_body['title']).to eq('Unprocessable Entity')
                  expect(response_body['status']).to eq('422')
                  expect(response_body['detail']).to include(detail)
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
                detail = 'Could not find an Accredited Representative with poa code: AG3'

                post request_path, params: request_body, headers: auth_header

                response_body = JSON.parse(response.body)['errors'][0]

                expect(response).to have_http_status(:not_found)
                expect(response_body['title']).to eq('Resource not found')
                expect(response_body['status']).to eq('404')
                expect(response_body['detail']).to include(detail)
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

        context 'lighthouse_claims_v2_poa_requests_skip_bgs disabled' do
          before do
            allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_v2_poa_requests_skip_bgs).and_return(false)
          end

          let(:request_body) do
            Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                            'power_of_attorney', 'request_representative', 'valid_no_claimant.json').read
          end

          let(:orchestrator_res) do
            {
              'addressLine1' => '2719 Hyperion Ave', 'addressLine2' => 'Apt 2', 'addressLine3' => nil,
              'changeAddressAuth' => 'true', 'city' => 'Los Angeles', 'claimantPtcpntId' => '187216',
              'claimantRelationship' => nil, 'formTypeCode' => '21-22 ', 'insuranceNumbers' => '1234567890',
              'limitationAlcohol' => 'true', 'limitationDrugAbuse' => 'true', 'limitationHIV' => 'true',
              'limitationSCA' => 'true', 'organizationName' => '083 - DISABLED AMERICAN VETERANS',
              'otherServiceBranch' => nil, 'phoneNumber' => '5555551234', 'poaCode' => '083', 'postalCode' => '92264',
              'procId' => '3858517', 'representativeFirstName' => 'John', 'representativeLastName' => 'Doe',
              'representativeLawFirmOrAgencyName' => nil, 'representativeTitle' => 'MyJob',
              'representativeType' => 'Recognized Veterans Service Organization', 'section7332Auth' => 'true',
              'serviceBranch' => 'Army', 'serviceNumber' => '123678453', 'state' => 'CA', 'vdcStatus' => 'Submitted',
              'veteranPtcpntId' => '187216', 'acceptedBy' => nil, 'claimantFirstName' => 'JESSE',
              'claimantLastName' => 'GRAY', 'claimantMiddleName' => nil, 'declinedBy' => nil, 'declinedReason' => nil,
              'secondaryStatus' => nil, 'veteranFirstName' => 'JESSE', 'veteranLastName' => 'GRAY',
              'veteranMiddleName' => nil, 'veteranSSN' => '796378881', 'veteranVAFileNumber' => '796378881'
            }
          end

          it 'returns the expected response from the blueprinter' do
            mock_ccg(scopes) do |auth_header|
              allow_any_instance_of(ClaimsApi::PowerOfAttorneyRequestService::Orchestrator)
                .to receive(:submit_request).and_return(orchestrator_res)

              post request_path, params: request_body, headers: auth_header

              response_body = JSON.parse(response.body)
              expected = JSON.parse(
                Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                'power_of_attorney', 'request_representative',
                                'expected_response_without_claimant.json').read
              )
              expected['data']['id'] = response_body['data']['id']

              expect(response).to have_http_status(:created)
              expect(response_body).to eq(expected)
            end
          end

          it 'does call the Orchestrator' do
            mock_ccg(scopes) do |auth_header|
              expect_any_instance_of(ClaimsApi::PowerOfAttorneyRequestService::Orchestrator)
                .to receive(:submit_request).and_return(orchestrator_res)

              post request_path, params: request_body, headers: auth_header
            end
          end

          it 'has Location in the response header' do
            mock_ccg(scopes) do |auth_header|
              expect_any_instance_of(ClaimsApi::PowerOfAttorneyRequestService::Orchestrator)
                .to receive(:submit_request).and_return(orchestrator_res)

              post request_path, params: request_body, headers: auth_header

              expect(response.headers).to have_key('Location')
            end
          end
        end

        context 'lighthouse_claims_v2_poa_requests_skip_bgs enabled' do
          before do
            allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_v2_poa_requests_skip_bgs).and_return(true)
          end

          let(:request_body) do
            Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                            'power_of_attorney', 'request_representative', 'valid_no_claimant.json').read
          end

          it 'returns the expected values from the blueprinter' do
            mock_ccg(scopes) do |auth_header|
              post request_path, params: request_body, headers: auth_header

              response_body = JSON.parse(response.body)
              expected = JSON.parse(
                Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                'power_of_attorney', 'request_representative',
                                'expected_response_without_claimant.json').read
              )
              expected['data']['id'] = response_body['data']['id']

              expect(response).to have_http_status(:created)
              expect(response_body).to eq(expected)
            end
          end

          it 'does not call the Orchestrator' do
            mock_ccg(scopes) do |auth_header|
              expect_any_instance_of(ClaimsApi::PowerOfAttorneyRequestService::Orchestrator)
                .not_to receive(:submit_request)

              post request_path, params: request_body, headers: auth_header
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
