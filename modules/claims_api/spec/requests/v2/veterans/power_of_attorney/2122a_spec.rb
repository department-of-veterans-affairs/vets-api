# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../../rails_helper'
require 'token_validation/v2/client'
require 'bgs_service/local_bgs'

RSpec.describe 'ClaimsApi::V1::PowerOfAttorney::2122a', type: :request do
  let(:veteran_id) { '1013062086V794840' }
  let(:appoint_individual_path) { "/services/claims/v2/veterans/#{veteran_id}/2122a" }
  let(:validate2122a_path) { "/services/claims/v2/veterans/#{veteran_id}/2122a/validate" }
  let(:scopes) { %w[system/claim.write system/claim.read] }
  let(:individual_poa_code) { '072' }
  let(:organization_poa_code) { '067' }
  let(:bgs_poa) { { person_org_name: "#{individual_poa_code} name-here" } }
  let(:local_bgs) { ClaimsApi::LocalBGS }

  describe 'PowerOfAttorney' do
    before do
      FactoryBot.create(:veteran_representative, representative_id: '12345', poa_codes: [individual_poa_code])
      FactoryBot.create(:veteran_representative, representative_id: '999999999999', poa_codes: [organization_poa_code])

      Flipper.disable(:lighthouse_claims_api_poa_dependent_claimants)
    end

    describe 'appoint_individual' do
      let(:data) do
        {
          data: {
            attributes: {
              veteran: {
                address: {
                  addressLine1: '123',
                  city: 'city',
                  stateCode: 'OR',
                  country: 'US',
                  zipCode: '12345'
                }
              },
              representative: {
                poaCode: individual_poa_code,
                registrationNumber: '12345',
                type: 'ATTORNEY',
                address: {
                  addressLine1: '123',
                  city: 'city',
                  country: 'US',
                  zipCode: '12345'
                }
              }
            }
          }
        }
      end

      let(:claimant_data) do
        {
          data: {
            attributes: {
              veteran: {
                address: {
                  addressLine1: '123',
                  city: 'city',
                  stateCode: 'OR',
                  country: 'US',
                  zipCode: '12345'
                }
              },
              representative: {
                poaCode: individual_poa_code,
                registrationNumber: '12345',
                type: 'ATTORNEY',
                address: {
                  addressLine1: '123',
                  city: 'city',
                  stateCode: 'OR',
                  country: 'US',
                  zipCode: '12345'
                }
              },
              claimant: {
                claimantId: '1013062086V794840',
                address: {
                  addressLine1: '123',
                  city: 'city',
                  stateCode: 'OR',
                  country: 'US',
                  zipCode: '12345'
                },
                relationship: 'spouse'
              }
            }
          }
        }
      end

      context 'when a POA code isn\'t provided' do
        it 'returns a 422 error code' do
          mock_ccg(scopes) do |auth_header|
            data[:data][:attributes][:representative] = nil

            post appoint_individual_path, params: data.to_json, headers: auth_header
            expect(response).to have_http_status(:unprocessable_entity)
          end
        end
      end

      context 'CCG (Client Credentials Grant) flow' do
        context 'when provided' do
          context 'when valid' do
            it 'returns a 202' do
              VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                mock_ccg(scopes) do |auth_header|
                  expect_any_instance_of(local_bgs).to receive(:find_poa_by_participant_id)
                    .and_return(bgs_poa)
                  allow_any_instance_of(local_bgs).to receive(:find_poa_history_by_ptcpnt_id)
                    .and_return({ person_poa_history: nil })

                  post appoint_individual_path, params: data.to_json, headers: auth_header
                  expect(response).to have_http_status(:accepted)
                end
              end
            end

            describe 'lighthouse_claims_api_poa_dependent_claimants feature' do
              let(:request_body) do
                Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                'power_of_attorney', '2122a', 'valid.json').read
              end

              let(:user_profile) do
                MPI::Responses::FindProfileResponse.new(
                  status: :ok,
                  profile: MPI::Models::MviProfile.new(
                    given_names: %w[Not Under],
                    family_name: 'Test',
                    participant_id: '123',
                    ssn: '123456789'
                  )
                )
              end

              let(:claimant_data) do
                {
                  claimantId: '456', # dependentʼs ICN
                  address: {
                    addressLine1: '123 anystreet',
                    city: 'anytown',
                    stateCode: 'OR',
                    country: 'USA',
                    zipCode: '12345'
                  },
                  relationship: 'Child'
                }
              end

              before do
                allow_any_instance_of(ClaimsApi::V2::Veterans::PowerOfAttorney::BaseController)
                  .to receive(:user_profile).and_return(user_profile)
                allow_any_instance_of(ClaimsApi::V2::Veterans::PowerOfAttorney::BaseController)
                  .to receive(:current_poa).and_return('123')
                allow_any_instance_of(ClaimsApi::DependentClaimantVerificationService)
                  .to receive(:validate_poa_code_exists!).and_return(nil)
                allow_any_instance_of(ClaimsApi::DependentClaimantVerificationService)
                  .to receive(:validate_dependent_by_participant_id!).and_return(nil)
              end

              context 'when the lighthouse_claims_api_poa_dependent_claimants feature is enabled' do
                before do
                  allow_any_instance_of(ClaimsApi::V2::Veterans::PowerOfAttorney::BaseController)
                    .to receive(:disable_jobs?).and_return(false)
                  Flipper.enable(:lighthouse_claims_api_poa_dependent_claimants)
                end

                context 'and the request includes a claimant' do
                  it 'enqueues the PoaFormBuilderJob' do
                    VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                      mock_ccg(scopes) do |auth_header|
                        json = JSON.parse(request_body)
                        json['data']['attributes']['claimant'] = claimant_data
                        request_body = json.to_json

                        expect do
                          post appoint_individual_path, params: request_body, headers: auth_header
                        end.to change(ClaimsApi::V2::PoaFormBuilderJob.jobs, :size).by(1)
                      end
                    end
                  end

                  it 'adds dependent values to the auth_headers when flipper enabled' do
                    VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                      mock_ccg(scopes) do |auth_header|
                        json = JSON.parse(request_body)
                        json['data']['attributes']['claimant'] = claimant_data
                        request_body = json.to_json

                        post appoint_individual_path, params: request_body, headers: auth_header

                        poa_id = JSON.parse(response.body)['data']['id']
                        poa = ClaimsApi::PowerOfAttorney.find(poa_id)
                        auth_headers = poa.auth_headers
                        expect(auth_headers).to have_key('dependent')
                      end
                    end
                  end
                end
              end

              context 'when the lighthouse_claims_api_poa_dependent_claimants feature is disabled' do
                before do
                  Flipper.disable(:lighthouse_claims_api_poa_dependent_claimants)
                end

                it 'does not add the dependent object to the auth_headers' do
                  VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                    mock_ccg(scopes) do |auth_header|
                      json = JSON.parse(request_body)
                      json['data']['attributes']['claimant'] = claimant_data
                      request_body = json.to_json

                      post appoint_individual_path, params: request_body, headers: auth_header

                      poa_id = JSON.parse(response.body)['data']['id']
                      poa = ClaimsApi::PowerOfAttorney.find(poa_id)
                      auth_headers = poa.auth_headers
                      expect(auth_headers).not_to have_key('dependent')
                    end
                  end
                end
              end
            end
          end

          context 'when not valid' do
            it 'returns a 401' do
              post appoint_individual_path, params: data.to_json, headers: { 'Authorization' => 'Bearer HelloWorld' }

              expect(response).to have_http_status(:unauthorized)
            end
          end

          context 'when claimant data is included' do
            shared_context 'claimant data setup' do
              before do
                allow_any_instance_of(local_bgs).to receive(:find_poa_by_participant_id).and_return(bgs_poa)
                allow_any_instance_of(local_bgs)
                  .to receive(:find_poa_history_by_ptcpnt_id).and_return({ person_poa_history: nil })
              end
            end

            context 'it is conditionally validated' do
              include_context 'claimant data setup'

              it 'returns a 202 when all conditionally required data is present' do
                mock_ccg(scopes) do |auth_header|
                  VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                    post appoint_individual_path, params: claimant_data.to_json, headers: auth_header
                  end
                  expect(response).to have_http_status(:accepted)
                end
              end

              it 'returns a 422 if claimant.address.addressLine1 is not provided' do
                mock_ccg(scopes) do |auth_header|
                  claimant_data[:data][:attributes][:claimant][:address][:addressLine1] = nil
                  VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                    post appoint_individual_path, params: claimant_data.to_json, headers: auth_header
                  end
                  expect(response).to have_http_status(:unprocessable_entity)
                  response_body = JSON.parse(response.body)
                  expect(response_body['errors'][0]['detail']).to eq(
                    "If claimant is present 'addressLine1' must be filled in"
                  )
                end
              end

              it 'returns a 422 if claimant.address.city is not provided' do
                mock_ccg(scopes) do |auth_header|
                  claimant_data[:data][:attributes][:claimant][:address][:city] = nil
                  VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                    post appoint_individual_path, params: claimant_data.to_json, headers: auth_header
                  end
                  expect(response).to have_http_status(:unprocessable_entity)
                  response_body = JSON.parse(response.body)
                  expect(response_body['errors'][0]['detail']).to eq(
                    "If claimant is present 'city' must be filled in"
                  )
                end
              end

              it 'returns a 422 if claimant.address.stateCode is not provided' do
                mock_ccg(scopes) do |auth_header|
                  claimant_data[:data][:attributes][:claimant][:address][:stateCode] = nil
                  VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                    post appoint_individual_path, params: claimant_data.to_json, headers: auth_header
                  end
                  expect(response).to have_http_status(:unprocessable_entity)
                  response_body = JSON.parse(response.body)
                  expect(response_body['errors'][0]['detail']).to eq(
                    "If claimant is present 'stateCode' must be filled in"
                  )
                end
              end

              it 'returns a 422 if claimant.address.country is not provided' do
                mock_ccg(scopes) do |auth_header|
                  claimant_data[:data][:attributes][:claimant][:address][:country] = nil
                  VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                    post appoint_individual_path, params: claimant_data.to_json, headers: auth_header
                  end
                  expect(response).to have_http_status(:unprocessable_entity)
                  response_body = JSON.parse(response.body)
                  expect(response_body['errors'][0]['detail']).to eq(
                    "If claimant is present 'country' must be filled in"
                  )
                end
              end

              it 'returns a 422 if claimant.address.zipCode is not provided' do
                mock_ccg(scopes) do |auth_header|
                  claimant_data[:data][:attributes][:claimant][:address][:zipCode] = nil
                  VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                    post appoint_individual_path, params: claimant_data.to_json, headers: auth_header
                  end
                  expect(response).to have_http_status(:unprocessable_entity)
                  response_body = JSON.parse(response.body)
                  expect(response_body['errors'][0]['detail']).to eq(
                    "If claimant is present 'zipCode' must be filled in"
                  )
                end
              end

              it 'returns a 422 if claimant.relationship is not provided' do
                VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                  mock_ccg(scopes) do |auth_header|
                    claimant_data[:data][:attributes][:claimant][:relationship] = nil

                    post appoint_individual_path, params: claimant_data.to_json, headers: auth_header
                    expect(response).to have_http_status(:unprocessable_entity)
                    response_body = JSON.parse(response.body)
                    expect(response_body['errors'][0]['detail']).to eq(
                      "If claimant is present 'relationship' must be filled in"
                    )
                  end
                end
              end

              describe 'with missing first and last name' do
                let(:no_first_last_name_target_veteran) do
                  OpenStruct.new(
                    icn: '1012832025V743496',
                    first_name: '',
                    last_name: '',
                    birth_date: '19630211',
                    loa: { current: 3, highest: 3 },
                    edipi: nil,
                    ssn: '796043735',
                    participant_id: '600061742',
                    mpi: OpenStruct.new(
                      icn: '1012832025V743496',
                      profile: OpenStruct.new(ssn: '796043735')
                    )
                  )
                end

                it 'returns a 422 if first and last name is not present' do
                  VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                    mock_ccg(scopes) do |auth_header|
                      allow_any_instance_of(ClaimsApi::V2::ApplicationController)
                        .to receive(:target_veteran).and_return(no_first_last_name_target_veteran)

                      post appoint_individual_path, params: claimant_data.to_json, headers: auth_header
                      expect(response).to have_http_status(:unprocessable_entity)
                      response_body = JSON.parse(response.body)
                      expect(response_body['errors'][0]['detail']).to eq(
                        'Must have either first or last name'
                      )
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    describe 'validate2122a' do
      let(:data) do
        {
          data: {
            attributes: {
              veteran: {
                address: {
                  addressLine1: '123',
                  city: 'city',
                  country: 'US',
                  zipCode: '12345'
                }
              },
              representative: {
                poaCode: individual_poa_code,
                type: 'ATTORNEY',
                address: {
                  addressLine1: '123',
                  city: 'city',
                  country: 'US',
                  zipCode: '12345'
                }
              }
            }
          }
        }
      end

      context 'CCG (Client Credentials Grant) flow' do
        context 'when provided' do
          context 'when valid' do
            context 'when the request data is not a valid json object' do
              let(:data) { '123abc' }

              it 'returns a meaningful 422' do
                mock_ccg(%w[claim.write claim.read]) do |auth_header|
                  detail = 'The request body is not a valid JSON object: '

                  post validate2122a_path, params: data, headers: auth_header

                  response_body = JSON.parse(response.body)['errors'][0]

                  expect(response).to have_http_status(:unprocessable_entity)
                  expect(response_body['title']).to eq('Unprocessable entity')
                  expect(response_body['status']).to eq('422')
                  expect(response_body['detail']).to eq(detail)
                end
              end
            end

            context 'when the request data is a valid json object' do
              context 'when the Veteran ICN is not found in MPI' do
                it 'returns a meaningful 404' do
                  mock_ccg(%w[claim.write claim.read]) do |auth_header|
                    allow_any_instance_of(ClaimsApi::Veteran)
                      .to receive(:mpi_record?).and_return(false)

                    detail = "Unable to locate Veteran's ID/ICN in Master Person Index (MPI). " \
                             'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.'

                    post validate2122a_path, params: { data: { attributes: nil } }.to_json, headers: auth_header

                    response_body = JSON.parse(response.body)['errors'][0]

                    expect(response).to have_http_status(:not_found)
                    expect(response_body['title']).to eq('Resource not found')
                    expect(response_body['status']).to eq('404')
                    expect(response_body['detail']).to eq(detail)
                  end
                end
              end

              describe 'with missing first and last name' do
                let(:no_first_last_name_target_veteran) do
                  OpenStruct.new(
                    icn: '1012832025V743496',
                    first_name: '',
                    last_name: '',
                    birth_date: '19630211',
                    loa: { current: 3, highest: 3 },
                    edipi: nil,
                    ssn: '796043735',
                    participant_id: '600061742',
                    mpi: OpenStruct.new(
                      icn: '1012832025V743496',
                      profile: OpenStruct.new(ssn: '796043735')
                    )
                  )
                end
                let(:request_body) do
                  Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                  'power_of_attorney', '2122a', 'valid.json').read
                end

                it 'returns a 422 if first and last name is not present' do
                  VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                    mock_ccg(scopes) do |auth_header|
                      allow_any_instance_of(ClaimsApi::V2::ApplicationController)
                        .to receive(:target_veteran).and_return(no_first_last_name_target_veteran)

                      post validate2122a_path, params: request_body, headers: auth_header
                      expect(response).to have_http_status(:unprocessable_entity)
                      response_body = JSON.parse(response.body)
                      expect(response_body['errors'][0]['detail']).to eq(
                        'Must have either first or last name'
                      )
                    end
                  end
                end
              end

              describe 'with missing first name' do
                let(:no_first_name_target_veteran) do
                  OpenStruct.new(
                    icn: '1012832025V743496',
                    first_name: '',
                    last_name: 'Ford',
                    birth_date: '19630211',
                    loa: { current: 3, highest: 3 },
                    edipi: nil,
                    ssn: '796043735',
                    participant_id: '600061742',
                    mpi: OpenStruct.new(
                      icn: '1012832025V743496',
                      profile: OpenStruct.new(ssn: '796043735')
                    )
                  )
                end
                let(:request_body) do
                  Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                  'power_of_attorney', '2122a', 'valid.json').read
                end

                it 'returns a success response' do
                  VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                    mock_ccg(scopes) do |auth_header|
                      allow_any_instance_of(ClaimsApi::V2::ApplicationController)
                        .to receive(:target_veteran).and_return(no_first_name_target_veteran)

                      post validate2122a_path, params: request_body, headers: auth_header
                      expect(response).to have_http_status(:ok)
                    end
                  end
                end
              end

              context 'when the Veteran ICN is found in MPI' do
                context 'when the request data does not pass schema validation' do
                  let(:request_body) do
                    Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                    'power_of_attorney', '2122a', 'invalid_schema.json').read
                  end

                  it 'returns a meaningful 422' do
                    mock_ccg(%w[claim.write claim.read]) do |auth_header|
                      detail = 'The property /representative did not contain the required key poaCode'

                      post validate2122a_path, params: request_body, headers: auth_header

                      response_body = JSON.parse(response.body)['errors'][0]

                      expect(response).to have_http_status(:unprocessable_entity)
                      expect(response_body['title']).to eq('Unprocessable entity')
                      expect(response_body['status']).to eq('422')
                      expect(response_body['detail']).to eq(detail)
                    end
                  end
                end

                context 'when the request data passes schema validation' do
                  context 'when no representatives have the provided POA code' do
                    let(:request_body) do
                      Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                      'power_of_attorney', '2122a', 'invalid_poa.json').read
                    end

                    it 'returns a meaningful 404' do
                      mock_ccg(%w[claim.write claim.read]) do |auth_header|
                        detail = 'Could not find an Accredited Representative with registration number: 999999999999 ' \
                                 'and poa code: aaa'

                        post validate2122a_path, params: request_body, headers: auth_header
                        response_body = JSON.parse(response.body)['errors'][0]

                        expect(response).to have_http_status(:not_found)
                        expect(response_body['title']).to eq('Resource not found')
                        expect(response_body['status']).to eq('404')
                        expect(response_body['detail']).to eq(detail)
                      end
                    end
                  end

                  context 'when at least one representative has the provided POA code' do
                    let(:request_body) do
                      Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                      'power_of_attorney', '2122a', 'valid.json').read
                    end

                    it 'returns a meaningful 200' do
                      mock_ccg(%w[claim.write claim.read]) do |auth_header|
                        post validate2122a_path, params: request_body, headers: auth_header

                        response_body = JSON.parse(response.body)['data']

                        expect(response).to have_http_status(:ok)
                        expect(response_body['type']).to eq('form/21-22a/validation')
                        expect(response_body['attributes']['status']).to eq('valid')
                      end
                    end
                  end

                  context 'when the provided POA code is not a valid 2122a individual code' do
                    let(:request_body) do
                      Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                      'power_of_attorney', '2122a', 'invalid_poa.json').read
                    end

                    it 'returns a meaningful 404' do
                      mock_ccg(%w[claim.write claim.read]) do |auth_header|
                        detail = 'Could not find an Accredited Representative with registration number: 999999999999 and poa code: aaa' # rubocop:disable Layout/LineLength

                        post validate2122a_path, params: request_body, headers: auth_header
                        response_body = JSON.parse(response.body)['errors'][0]

                        expect(response).to have_http_status(:not_found)
                        expect(response_body['title']).to eq('Resource not found')
                        expect(response_body['status']).to eq('404')
                        expect(response_body['detail']).to eq(detail)
                      end
                    end
                  end

                  context 'when the lighthouse_claims_api_poa_dependent_claimants feature is enabled' do
                    let(:request_body) do
                      Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                      'power_of_attorney', '2122a', 'valid.json').read
                    end
                    let(:user_profile) do
                      MPI::Responses::FindProfileResponse.new(
                        status: :ok,
                        profile: MPI::Models::MviProfile.new(
                          given_names: %w[Not Under],
                          family_name: 'Test',
                          participant_id: '123'
                        )
                      )
                    end

                    before do
                      Flipper.enable(:lighthouse_claims_api_poa_dependent_claimants)

                      allow_any_instance_of(ClaimsApi::V2::Veterans::PowerOfAttorney::BaseController)
                        .to receive(:user_profile).and_return(user_profile)
                    end

                    context 'and the request includes a claimant' do
                      it 'calls validate_poa_code_exists! and validate_dependent_by_participant_id!' do
                        VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                          mock_ccg(%w[claim.write claim.read]) do |auth_header|
                            json = JSON.parse(request_body)
                            json['data']['attributes']['claimant'] = { claimantId: '123' }
                            request_body = json.to_json

                            expect_any_instance_of(ClaimsApi::DependentClaimantVerificationService)
                              .to receive(:validate_poa_code_exists!)
                            expect_any_instance_of(ClaimsApi::DependentClaimantVerificationService)
                              .to receive(:validate_dependent_by_participant_id!)

                            post validate2122a_path, params: request_body, headers: auth_header
                          end
                        end
                      end
                    end

                    context 'and the request does not include a claimant' do
                      it 'does not call validate_poa_code_exists! and validate_dependent_by_participant_id!' do
                        VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                          mock_ccg(%w[claim.write claim.read]) do |auth_header|
                            json = JSON.parse(request_body)
                            request_body = json.to_json

                            expect_any_instance_of(ClaimsApi::DependentClaimantVerificationService)
                              .not_to receive(:validate_poa_code_exists!)
                            expect_any_instance_of(ClaimsApi::DependentClaimantVerificationService)
                              .not_to receive(:validate_dependent_by_participant_id!)

                            post validate2122a_path, params: request_body, headers: auth_header
                          end
                        end
                      end
                    end
                  end

                  context 'when the lighthouse_claims_api_poa_dependent_claimants feature is disabled' do
                    let(:request_body) do
                      Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                      'power_of_attorney', '2122a', 'valid.json').read
                    end

                    before do
                      Flipper.disable(:lighthouse_claims_api_poa_dependent_claimants)
                    end

                    it 'does not call validate_poa_code_exists! and validate_dependent_by_participant_id!' do
                      VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                        mock_ccg(%w[claim.write claim.read]) do |auth_header|
                          json = JSON.parse(request_body)
                          json['data']['attributes']['claimant'] = { claimantId: '123' }
                          request_body = json.to_json

                          expect_any_instance_of(ClaimsApi::DependentClaimantVerificationService)
                            .not_to receive(:validate_poa_code_exists!)
                          expect_any_instance_of(ClaimsApi::DependentClaimantVerificationService)
                            .not_to receive(:validate_dependent_by_participant_id!)

                          post validate2122a_path, params: request_body, headers: auth_header
                        end
                      end
                    end
                  end

                  context 'when no claimantId is provided and other claimant data is present' do
                    let(:request_body) do
                      Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                      'power_of_attorney', '2122a', 'valid.json').read
                    end

                    let(:claimant) do
                      {
                        email: 'lillian@disney.com',
                        relationship: 'Spouse',
                        address: {
                          addressLine1: '2688 S Camino Real',
                          city: 'Palm Springs',
                          stateCode: 'CA',
                          country: 'US',
                          zipCode: '92264'
                        },
                        phone: {
                          areaCode: '555',
                          phoneNumber: '5551337'
                        }
                      }
                    end
                    let(:error_msg) { "If claimant is present 'claimantId' must be filled in" }

                    it 'returns a meaningful 422' do
                      mock_ccg(%w[claim.write claim.read]) do |auth_header|
                        json = JSON.parse(request_body)
                        json['data']['attributes']['claimant'] = claimant
                        request_body = json.to_json
                        post validate2122a_path, params: request_body, headers: auth_header

                        response_body = JSON.parse(response.body)['errors'][0]
                        expect(response).to have_http_status(:unprocessable_entity)
                        expect(response_body['detail']).to eq(error_msg)
                      end
                    end
                  end
                end
              end
            end
          end
        end

        context 'when not valid' do
          it 'returns a 401' do
            post validate2122a_path, headers: { 'Authorization' => 'Bearer HelloWorld' }

            expect(response).to have_http_status(:unauthorized)
          end
        end
      end
    end
  end
end
