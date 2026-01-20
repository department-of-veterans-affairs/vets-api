# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../../rails_helper'
require 'token_validation/v2/client'
require 'bgs_service/claimant_web_service'
require 'bgs_service/org_web_service'

RSpec.describe 'ClaimsApi::V1::PowerOfAttorney::2122', type: :request do
  let(:veteran_id) { '1013062086V794840' }
  let(:appoint_organization_path) { "/services/claims/v2/veterans/#{veteran_id}/2122" }
  let(:validate2122_path) { "/services/claims/v2/veterans/#{veteran_id}/2122/validate" }
  let(:scopes) { %w[system/claim.write system/claim.read] }
  let(:individual_poa_code) { 'A1H' }
  let(:organization_poa_code) { '083' }
  let(:bgs_poa) { { person_org_name: "#{individual_poa_code} name-here" } }
  let(:claimant_web_service) { ClaimsApi::ClaimantWebService }
  let(:org_web_service) { ClaimsApi::OrgWebService }

  describe 'PowerOfAttorney' do
    before do
      create(:veteran_representative, representative_id: '999999999999',
                                      poa_codes: [organization_poa_code])
      create(:veteran_organization, poa: organization_poa_code,
                                    name: "#{organization_poa_code} - DISABLED AMERICAN VETERANS")
      allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_poa_dependent_claimants).and_return(false)
    end

    describe 'submit2122' do
      let(:data) do
        {
          data: {
            attributes: {
              veteran: {
                address: {
                  addressLine1: '123',
                  city: 'city',
                  stateCode: 'OR',
                  countryCode: 'US',
                  zipCode: '12345'
                }
              },
              serviceOrganization: {
                poaCode: organization_poa_code.to_s,
                registrationNumber: '999999999999'
              }
            }
          }
        }
      end

      context 'CCG (Client Credentials Grant) flow' do
        context 'when provided' do
          context 'when valid' do
            it 'returns a 202' do
              mock_ccg(scopes) do |auth_header|
                allow_any_instance_of(claimant_web_service).to receive(:find_poa_by_participant_id)
                  .and_return(bgs_poa)
                allow_any_instance_of(org_web_service).to receive(:find_poa_history_by_ptcpnt_id)
                  .and_return({ person_poa_history: nil })
                mock_file_number_check

                post appoint_organization_path, params: data.to_json, headers: auth_header

                expect(response).to have_http_status(:accepted)
              end
            end

            context 'auth headers' do
              let(:poa) do
                VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                  mock_ccg(scopes) do |auth_header|
                    allow_any_instance_of(claimant_web_service).to receive(:find_poa_by_participant_id)
                      .and_return(bgs_poa)
                    allow_any_instance_of(org_web_service).to receive(:find_poa_history_by_ptcpnt_id)
                      .and_return({ person_poa_history: nil })
                    mock_file_number_check

                    post appoint_organization_path, params: data.to_json, headers: auth_header
                    poa_id = JSON.parse(response.body)['data']['id']
                    ClaimsApi::PowerOfAttorney.find(poa_id)
                  end
                end
              end

              it 'adds the file_number to the header' do
                expect(poa.auth_headers).to have_key('file_number')
              end
            end

            describe 'address validations' do
              let(:request_body) do
                Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                'power_of_attorney', '2122', 'valid.json').read
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

              describe 'conditionally required zipCode' do
                context 'when the country provided is US' do
                  it 'returns a 422 when no zipCode is included in the veteran data' do
                    VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                      mock_ccg(scopes) do |auth_header|
                        allow_any_instance_of(org_web_service).to receive(:find_poa_history_by_ptcpnt_id)
                          .and_return({ person_poa_history: nil })

                        json = JSON.parse(request_body)
                        json['data']['attributes']['veteran']['address']['zipCode'] = ''
                        body = json.to_json

                        post appoint_organization_path, params: body, headers: auth_header

                        response_body = JSON.parse(response.body)

                        expect(response).to have_http_status(:unprocessable_entity)
                        expect(response_body['errors'][0]['status']).to eq('422')
                        expect(response_body['errors'][0]['detail'])
                          .to eq("If 'countryCode' is 'US' then 'zipCode' is required.")
                      end
                    end
                  end
                end

                context 'when the country provided is not US' do
                  it 'returns a 202 when no zipCode is included in the veteran data' do
                    VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                      mock_ccg(scopes) do |auth_header|
                        allow_any_instance_of(claimant_web_service).to receive(:find_poa_by_participant_id)
                          .and_return(bgs_poa)
                        allow_any_instance_of(org_web_service).to receive(:find_poa_history_by_ptcpnt_id)
                          .and_return({ person_poa_history: nil })
                        mock_file_number_check

                        json = JSON.parse(request_body)
                        json['data']['attributes']['veteran']['address']['countryCode'] = 'AL'
                        json['data']['attributes']['veteran']['address']['zipCode'] = ''
                        body = json.to_json

                        post appoint_organization_path, params: body, headers: auth_header

                        expect(response).to have_http_status(:accepted)
                      end
                    end
                  end
                end
              end
            end

            describe 'lighthouse_claims_api_poa_dependent_claimants feature' do
              let(:request_body) do
                Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                'power_of_attorney', '2122', 'valid.json').read
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
                    countryCode: 'US',
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
                  allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_poa_dependent_claimants)
                                                      .and_return(true)
                  mock_file_number_check
                end

                context 'and the request includes a claimant' do
                  it 'enqueues the PoaFormBuilder job' do
                    VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                      mock_ccg(scopes) do |auth_header|
                        json = JSON.parse(request_body)
                        json['data']['attributes']['claimant'] = claimant_data
                        request_body = json.to_json

                        expect do
                          post appoint_organization_path, params: request_body, headers: auth_header
                        end.to change(ClaimsApi::V2::PoaFormBuilderJob.jobs, :size)
                      end
                    end
                  end

                  it 'adds dependent values to the auth_headers' do
                    VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                      mock_ccg(scopes) do |auth_header|
                        json = JSON.parse(request_body)
                        json['data']['attributes']['claimant'] = claimant_data
                        request_body = json.to_json

                        post appoint_organization_path, params: request_body, headers: auth_header

                        poa_id = JSON.parse(response.body)['data']['id']
                        poa = ClaimsApi::PowerOfAttorney.find(poa_id)
                        auth_headers = poa.auth_headers

                        expect(auth_headers).to have_key('dependent')
                      end
                    end
                  end

                  it 'adds cid to attributes' do
                    VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                      mock_ccg(scopes) do |auth_header|
                        json = JSON.parse(request_body)
                        json['data']['attributes']['claimant'] = claimant_data
                        request_body = json.to_json

                        post appoint_organization_path, params: request_body, headers: auth_header

                        poa_id = JSON.parse(response.body)['data']['id']
                        poa = ClaimsApi::PowerOfAttorney.find(poa_id)
                        expect(poa.cid).to eq('test-id-here')
                      end
                    end
                  end

                  it "does not add dependent values to the auth_headers if relationship is 'Self'" do
                    VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                      mock_ccg(scopes) do |auth_header|
                        json = JSON.parse(request_body)
                        json['data']['attributes']['claimant'] = claimant_data
                        json['data']['attributes']['claimant']['relationship'] = 'Self'
                        request_body = json.to_json

                        post appoint_organization_path, params: request_body, headers: auth_header

                        poa_id = JSON.parse(response.body)['data']['id']
                        poa = ClaimsApi::PowerOfAttorney.find(poa_id)
                        auth_headers = poa.auth_headers
                        expect(auth_headers).not_to have_key('dependent')
                      end
                    end
                  end
                end
              end

              context 'when the lighthouse_claims_api_poa_dependent_claimants feature is disabled' do
                before do
                  allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_poa_dependent_claimants)
                                                      .and_return false
                  mock_file_number_check
                end

                it 'does not add the dependent object to the auth_headers' do
                  VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                    mock_ccg(scopes) do |auth_header|
                      json = JSON.parse(request_body)
                      json['data']['attributes']['claimant'] = claimant_data
                      request_body = json.to_json

                      post appoint_organization_path, params: request_body, headers: auth_header

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
              post appoint_organization_path, params: data, headers: { 'Authorization' => 'Bearer HelloWorld' }

              expect(response).to have_http_status(:unauthorized)
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

            it 'returns a success response' do
              mock_ccg(scopes) do |auth_header|
                allow_any_instance_of(claimant_web_service).to receive(:find_poa_by_participant_id)
                  .and_return(bgs_poa)
                allow_any_instance_of(org_web_service).to receive(:find_poa_history_by_ptcpnt_id)
                  .and_return({ person_poa_history: nil })
                allow_any_instance_of(ClaimsApi::V2::ApplicationController)
                  .to receive(:target_veteran).and_return(no_first_name_target_veteran)
                mock_file_number_check

                post appoint_organization_path, params: data.to_json, headers: auth_header

                expect(response).to have_http_status(:accepted)
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

            it 'returns a 422' do
              mock_ccg(scopes) do |auth_header|
                allow_any_instance_of(org_web_service).to receive(:find_poa_history_by_ptcpnt_id)
                  .and_return({ person_poa_history: nil })
                allow_any_instance_of(ClaimsApi::V2::ApplicationController)
                  .to receive(:target_veteran).and_return(no_first_last_name_target_veteran)

                post appoint_organization_path, params: data.to_json, headers: auth_header

                response_body = JSON.parse(response.body)['errors'][0]

                expect(response).to have_http_status(:unprocessable_entity)
                expect(response_body['status']).to eq('422')
                expect(response_body['detail']).to eq('Must have either first or last name')
              end
            end
          end

          describe 'when validating the conditionally required zipCode' do
            let(:request_body) do
              Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                              'power_of_attorney', '2122', 'valid.json').read
            end

            context "when the country is 'US'" do
              let(:claimant_data) do
                {
                  claimantId: '456',
                  address: {
                    addressLine1: '123 anystreet',
                    city: 'anytown',
                    stateCode: 'OR',
                    countryCode: 'US',
                    zipCode: ''
                  },
                  relationship: 'Child'
                }
              end

              it 'returns a 422 with no zipCode' do
                VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                  mock_ccg(scopes) do |auth_header|
                    allow_any_instance_of(org_web_service).to receive(:find_poa_history_by_ptcpnt_id)
                      .and_return({ person_poa_history: nil })

                    json = JSON.parse(request_body)
                    json['data']['attributes']['claimant'] = claimant_data
                    request_data = json.to_json

                    post appoint_organization_path, params: request_data, headers: auth_header

                    response_body = JSON.parse(response.body)['errors'][0]

                    expect(response).to have_http_status(:unprocessable_entity)
                    expect(response_body['status']).to eq('422')
                    expect(response_body['detail']).to eq("If 'countryCode' is 'US' then 'zipCode' is required.")
                  end
                end
              end
            end

            context "when the country is not 'US'" do
              let(:claimant_data) do
                {
                  claimantId: '456',
                  address: {
                    addressLine1: '123 anystreet',
                    city: 'anytown',
                    stateCode: 'OR',
                    countryCode: 'AL',
                    zipCode: ''
                  },
                  relationship: 'Child'
                }
              end

              it 'returns a 202 with no zipCode' do
                VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                  mock_ccg(scopes) do |auth_header|
                    allow_any_instance_of(claimant_web_service).to receive(:find_poa_by_participant_id)
                      .and_return(bgs_poa)
                    allow_any_instance_of(org_web_service).to receive(:find_poa_history_by_ptcpnt_id)
                      .and_return({ person_poa_history: nil })
                    mock_file_number_check

                    json = JSON.parse(request_body)
                    json['data']['attributes']['claimant'] = claimant_data
                    request_data = json.to_json

                    post appoint_organization_path, params: request_data, headers: auth_header

                    expect(response).to have_http_status(:accepted)
                  end
                end
              end
            end
          end

          context 'when validating email values' do
            context 'when the email is valid' do
              before do
                allow_any_instance_of(claimant_web_service).to receive(:find_poa_by_participant_id)
                  .and_return(bgs_poa)
                allow_any_instance_of(org_web_service).to receive(:find_poa_history_by_ptcpnt_id)
                  .and_return({ person_poa_history: nil })
                mock_file_number_check
              end

              it 'allows an empty string' do
                data[:data][:attributes][:veteran][:email] = ''
                mock_ccg(scopes) do |auth_header|
                  post appoint_organization_path, params: data.to_json, headers: auth_header

                  expect(response).to have_http_status(:accepted)
                end
              end

              it "allows a valid 'normal' looking email" do
                data[:data][:attributes][:veteran][:email] = 'valid@email.com'
                mock_ccg(scopes) do |auth_header|
                  post appoint_organization_path, params: data.to_json, headers: auth_header

                  expect(response).to have_http_status(:accepted)
                end
              end
            end

            context 'when the email is invalid' do
              it 'denies an invalid value' do
                data[:data][:attributes][:veteran][:email] = 'thisisnotavalidemailatall'
                mock_ccg(scopes) do |auth_header|
                  post appoint_organization_path, params: data.to_json, headers: auth_header

                  json_response = JSON.parse(response.body)

                  expect(response).to have_http_status(:unprocessable_entity)
                  expect(json_response['errors'][0]['detail']).to eq(
                    'The property /veteran/email did not match the following requirements: ' \
                    '{"description"=>"Email address for the veteran.", "type"=>"string", ' \
                    '"pattern"=>"^(?!.*\\\\s).+@.+\\\\..+|^$", "maxLength"=>61, "example"=>' \
                    '"veteran@example.com"}'
                  )
                end
              end

              it 'denies an empty string' do
                data[:data][:attributes][:veteran][:email] = ' '
                mock_ccg(scopes) do |auth_header|
                  post appoint_organization_path, params: data.to_json, headers: auth_header

                  json_response = JSON.parse(response.body)

                  expect(response).to have_http_status(:unprocessable_entity)
                  expect(json_response['errors'][0]['detail']).to eq(
                    'The property /veteran/email did not match the following requirements: ' \
                    '{"description"=>"Email address for the veteran.", "type"=>"string", ' \
                    '"pattern"=>"^(?!.*\\\\s).+@.+\\\\..+|^$", "maxLength"=>61, "example"=>' \
                    '"veteran@example.com"}'
                  )
                end
              end
            end
          end
        end
      end

      context 'scopes' do
        let(:invalid_scopes) { %w[system/526-pdf.override] }
        let(:poa_scopes) { %w[system/claim.write] }

        context 'POA organization' do
          it 'returns a 202 response when successful' do
            mock_ccg_for_fine_grained_scope(poa_scopes) do |auth_header|
              allow_any_instance_of(claimant_web_service).to receive(:find_poa_by_participant_id)
                .and_return(bgs_poa)
              allow_any_instance_of(org_web_service).to receive(:find_poa_history_by_ptcpnt_id)
                .and_return({ person_poa_history: nil })
              mock_file_number_check

              post appoint_organization_path, params: data.to_json, headers: auth_header
              expect(response).to have_http_status(:accepted)
            end
          end

          it 'returns a 401 unauthorized with incorrect scopes' do
            mock_ccg_for_fine_grained_scope(invalid_scopes) do |auth_header|
              post appoint_organization_path, params: data.to_json, headers: auth_header

              expect(response).to have_http_status(:unauthorized)
            end
          end
        end
      end

      context 'creating a rep with the same representative_id' do
        let!(:existing) do
          create(
            :veteran_representative,
            representative_id: '555',
            poa_codes: [organization_poa_code]
          )
        end

        let(:rep) do
          build(
            :veteran_representative,
            representative_id: existing.representative_id,
            poa_codes: [organization_poa_code]
          )
        end

        it 'raises RecordNotUnique and does not create a second instance' do
          expect { rep.save! }.to raise_error(ActiveRecord::RecordNotUnique)
          expect(Veteran::Service::Representative.where(representative_id: '999999999999').count).to eq(1)
        end
      end
    end

    describe 'validate2122' do
      context 'CCG (Client Credentials Grant) flow' do
        context 'when provided' do
          context 'when valid' do
            context 'when the request data is not a valid json object' do
              let(:data) { '123abc' }

              it 'returns a meaningful 422' do
                mock_ccg(%w[claim.write claim.read]) do |auth_header|
                  detail = 'The request body is not a valid JSON object: '

                  post validate2122_path, params: data, headers: auth_header

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
                                  'power_of_attorney', '2122', 'invalid_schema.json').read
                end

                it 'returns a meaningful 422' do
                  mock_ccg(%w[claim.write claim.read]) do |auth_header|
                    detail = 'The property /serviceOrganization did not contain the required key poaCode'

                    post validate2122_path, params: request_body, headers: auth_header

                    response_body = JSON.parse(response.body)['errors'][0]

                    expect(response).to have_http_status(:unprocessable_entity)
                    expect(response_body['title']).to eq('Unprocessable entity')
                    expect(response_body['status']).to eq('422')
                    expect(response_body['detail']).to eq(detail)
                  end
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
                                'power_of_attorney', '2122', 'valid.json').read
              end

              it 'returns an error response' do
                mock_ccg(scopes) do |auth_header|
                  allow_any_instance_of(org_web_service).to receive(:find_poa_history_by_ptcpnt_id)
                    .and_return({ person_poa_history: nil })
                  allow_any_instance_of(ClaimsApi::V2::ApplicationController)
                    .to receive(:target_veteran).and_return(no_first_last_name_target_veteran)

                  post validate2122_path, params: request_body, headers: auth_header
                  response_body = JSON.parse(response.body)['errors'][0]
                  expect(response).to have_http_status(:unprocessable_entity)
                  expect(response_body['status']).to eq('422')
                  expect(response_body['detail']).to eq('Must have either first or last name')
                end
              end
            end

            describe 'with non-US countryCode provided without areaCode' do
              let(:veteran) do
                {
                  address: {
                    addressLine1: '123',
                    addressLine2: '2a',
                    city: 'city',
                    countryCode: 'US',
                    stateCode: 'OR',
                    zipCode: '12345',
                    zipCodeSuffix: '6789'
                  },
                  phone: {
                    countryCode: '44',
                    phoneNumber: '3664242'
                  }
                }
              end
              let(:request_body) do
                Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                'power_of_attorney', '2122', 'valid.json').read
              end

              it 'returns a 200' do
                mock_ccg(scopes) do |auth_header|
                  allow_any_instance_of(org_web_service).to receive(:find_poa_history_by_ptcpnt_id)
                    .and_return({ person_poa_history: nil })
                  json = JSON.parse(request_body)
                  json['data']['attributes']['veteran'] = veteran
                  request_body = json.to_json

                  post validate2122_path, params: request_body, headers: auth_header
                  expect(response).to have_http_status(:ok)
                end
              end
            end

            context 'when the request data passes schema validation' do
              context 'when no representatives have the provided POA code' do
                let(:request_body) do
                  Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                  'power_of_attorney', '2122', 'invalid_poa.json').read
                end

                it 'returns a meaningful 404' do
                  mock_ccg(%w[claim.write claim.read]) do |auth_header|
                    detail = 'Could not find an Accredited Representative with registration number: 999999999999 ' \
                             'and poa code: aaa'

                    post validate2122_path, params: request_body, headers: auth_header

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
                                  'power_of_attorney', '2122', 'valid.json').read
                end

                it 'returns 200' do
                  mock_ccg(%w[claim.write claim.read]) do |auth_header|
                    post validate2122_path, params: request_body, headers: auth_header

                    response_body = JSON.parse(response.body)['data']

                    expect(response).to have_http_status(:ok)
                    expect(response_body['type']).to eq('form/21-22/validation')
                    expect(response_body['attributes']['status']).to eq('valid')
                  end
                end
              end

              context 'when the lighthouse_claims_api_poa_dependent_claimants feature is enabled' do
                let(:request_body) do
                  Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                  'power_of_attorney', '2122', 'valid.json').read
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
                  allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_poa_dependent_claimants)
                                                      .and_return true

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

                        post validate2122_path, params: request_body, headers: auth_header
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

                        post validate2122_path, params: request_body, headers: auth_header
                      end
                    end
                  end
                end
              end

              context 'when the lighthouse_claims_api_poa_dependent_claimants feature is disabled' do
                let(:request_body) do
                  Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                  'power_of_attorney', '2122', 'valid.json').read
                end

                before do
                  allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_poa_dependent_claimants)
                                                      .and_return false
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

                      post validate2122_path, params: request_body, headers: auth_header
                    end
                  end
                end
              end

              context 'when no claimantId is provided and other claimant data is present' do
                let(:request_body) do
                  Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                  'power_of_attorney', '2122', 'valid.json').read
                end

                let(:claimant) do
                  {
                    email: 'lillian@disney.com',
                    relationship: 'Spouse',
                    address: {
                      addressLine1: '2688 S Camino Real',
                      city: 'Palm Springs',
                      stateCode: 'CA',
                      countryCode: 'US',
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
                  VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                    mock_ccg(%w[claim.write claim.read]) do |auth_header|
                      json = JSON.parse(request_body)
                      json['data']['attributes']['claimant'] = claimant
                      request_body = json.to_json
                      post validate2122_path, params: request_body, headers: auth_header

                      response_body = JSON.parse(response.body)['errors'][0]
                      expect(response).to have_http_status(:unprocessable_entity)
                      expect(response_body['detail']).to eq(error_msg)
                    end
                  end
                end
              end

              describe 'phone number validation' do
                let(:request_body) do
                  Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                  'power_of_attorney', '2122', 'valid.json').read
                end

                let(:claimant) do
                  {
                    claimantId: '456',
                    email: 'lillian@disney.com',
                    relationship: 'Spouse',
                    address: {
                      addressLine1: '2688 S Camino Real',
                      city: 'Palm Springs',
                      stateCode: 'CA',
                      countryCode: 'US',
                      zipCode: '92264'
                    },
                    phone: {
                      areaCode: '303',
                      phoneNumber: '5551337'
                    }
                  }
                end
                let(:claimant_international) do
                  {
                    claimantId: '456',
                    email: 'lillian@disney.com',
                    relationship: 'Spouse',
                    address: {
                      addressLine1: '2688 S Camino Real',
                      city: 'Palm Springs',
                      stateCode: 'CA',
                      countryCode: 'US',
                      zipCode: '92264'
                    },
                    phone: {
                      countryCode: '1',
                      areaCode: '303',
                      phoneNumber: '5551337'
                    }
                  }
                end

                context 'when claimant.phone.countryCode is "1" and areaCode is not provided' do
                  let(:error_msg) do
                    'The property /claimant/phone/areaCode did not match the following requirements:'
                  end

                  it 'returns a meaningful 422' do
                    VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                      mock_ccg(%w[claim.write claim.read]) do |auth_header|
                        json = JSON.parse(request_body)
                        claimant_international[:phone][:areaCode] = nil
                        json['data']['attributes']['claimant'] = claimant_international
                        request_body = json.to_json
                        post validate2122_path, params: request_body, headers: auth_header

                        response_body = JSON.parse(response.body)['errors'][0]
                        expect(response).to have_http_status(:unprocessable_entity)
                        expect(response_body['detail']).to include(error_msg)
                      end
                    end
                  end
                end

                context 'when claimant.phone.countryCode is "1" and areaCode is provided' do
                  it 'returns a 200' do
                    VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                      mock_ccg(%w[claim.write claim.read]) do |auth_header|
                        json = JSON.parse(request_body)
                        claimant_international[:phone][:phoneNumber] = '5551337'
                        json['data']['attributes']['claimant'] = claimant_international
                        request_body = json.to_json
                        post validate2122_path, params: request_body, headers: auth_header

                        expect(response).to have_http_status(:ok)
                      end
                    end
                  end
                end

                context 'when claimant.phoneNumber contains a dash' do
                  it 'returns a 200' do
                    VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                      mock_ccg(%w[claim.write claim.read]) do |auth_header|
                        json = JSON.parse(request_body)
                        claimant[:phone][:phoneNumber] = '555-1337'
                        json['data']['attributes']['claimant'] = claimant
                        request_body = json.to_json
                        post validate2122_path, params: request_body, headers: auth_header

                        expect(response).to have_http_status(:ok)
                      end
                    end
                  end
                end

                context 'when it a US number contains a space' do
                  it 'returns a 200' do
                    VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                      mock_ccg(%w[claim.write claim.read]) do |auth_header|
                        json = JSON.parse(request_body)
                        claimant[:phone][:phoneNumber] = '555 1337'
                        json['data']['attributes']['claimant'] = claimant
                        request_body = json.to_json
                        post validate2122_path, params: request_body, headers: auth_header

                        expect(response).to have_http_status(:ok)
                      end
                    end
                  end
                end

                context 'when an international number contains dashes' do
                  it 'returns a 200' do
                    VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                      mock_ccg(%w[claim.write claim.read]) do |auth_header|
                        json = JSON.parse(request_body)
                        claimant_international[:phone][:phoneNumber] = '44-1234-567890'
                        json['data']['attributes']['claimant'] = claimant_international
                        request_body = json.to_json
                        post validate2122_path, params: request_body, headers: auth_header

                        expect(response).to have_http_status(:ok)
                      end
                    end
                  end
                end

                context 'when an international number contains spaces' do
                  it 'returns a 200' do
                    VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
                      mock_ccg(%w[claim.write claim.read]) do |auth_header|
                        json = JSON.parse(request_body)
                        claimant_international[:phone][:phoneNumber] = '44 1234 567890'
                        json['data']['attributes']['claimant'] = claimant_international
                        request_body = json.to_json
                        post validate2122_path, params: request_body, headers: auth_header

                        expect(response).to have_http_status(:ok)
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
            post validate2122_path, headers: { 'Authorization' => 'Bearer HelloWorld' }

            expect(response).to have_http_status(:unauthorized)
          end
        end
      end
    end
  end
end
