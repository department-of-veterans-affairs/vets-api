# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../rails_helper'
require 'token_validation/v2/client'
require 'bgs_service/local_bgs'

RSpec.describe 'Power Of Attorney', type: :request do
  let(:veteran_id) { '1013062086V794840' }
  let(:get_poa_path) { "/services/claims/v2/veterans/#{veteran_id}/power-of-attorney" }
  let(:appoint_individual_path) { "/services/claims/v2/veterans/#{veteran_id}/2122a" }
  let(:appoint_organization_path) { "/services/claims/v2/veterans/#{veteran_id}/2122" }
  let(:validate2122_path) { "/services/claims/v2/veterans/#{veteran_id}/2122/validate" }
  let(:validate2122a_path) { "/services/claims/v2/veterans/#{veteran_id}/2122a/validate" }
  let(:status_path) { "/services/claims/v2/veterans/#{veteran_id}/power-of-attorney/" }
  let(:scopes) { %w[system/claim.write system/claim.read] }
  let(:individual_poa_code) { 'A1H' }
  let(:organization_poa_code) { '083' }
  let(:bgs_poa) { { person_org_name: "#{individual_poa_code} name-here" } }
  let(:local_bgs) { ClaimsApi::LocalBGS }

  describe 'PowerOfAttorney' do
    before do
      Veteran::Service::Representative.create!(representative_id: '12345', poa_codes: [individual_poa_code],
                                               first_name: 'Abraham', last_name: 'Lincoln')
      Veteran::Service::Representative.create!(representative_id: '67890', poa_codes: [organization_poa_code],
                                               first_name: 'George', last_name: 'Washington')
      Veteran::Service::Organization.create!(poa: organization_poa_code,
                                             name: "#{organization_poa_code} - DISABLED AMERICAN VETERANS")
    end

    describe 'show' do
      context 'CCG (Client Credentials Grant) flow' do
        context 'when provided' do
          context 'when valid' do
            context 'when current poa code does not exist' do
              it 'returns a 200' do
                mock_ccg(scopes) do |auth_header|
                  allow(BGS::PowerOfAttorneyVerifier).to receive(:new).and_return(OpenStruct.new(current_poa_code: nil))

                  get get_poa_path, headers: auth_header

                  expect(response.status).to eq(200)
                end
              end
            end

            context 'when the current poa is not associated with an organization' do
              context 'when multiple representatives share the poa code' do
                context 'when there is one unique representative_id' do
                  before do
                    create(:representative, representative_id: '12345', first_name: 'Bob', last_name: 'Law',
                                            poa_codes: ['ABC'], phone: '123-456-7890')
                    create(:representative, representative_id: '12345', first_name: 'Robert', last_name: 'Lawlaw',
                                            poa_codes: ['ABC'], phone: '321-654-0987')
                  end

                  it 'returns the most recently created representative' do
                    mock_ccg(scopes) do |auth_header|
                      allow(BGS::PowerOfAttorneyVerifier)
                        .to receive(:new)
                        .and_return(OpenStruct.new(current_poa_code: 'ABC'))

                      expected_response = {
                        'data' => {
                          'type' => 'individual',
                          'attributes' => {
                            'code' => 'ABC',
                            'name' => 'Robert Lawlaw',
                            'phoneNumber' => '321-654-0987'
                          }
                        }
                      }

                      get get_poa_path, headers: auth_header

                      response_body = JSON.parse(response.body)

                      expect(response).to have_http_status(:ok)
                      expect(response_body).to eq(expected_response)
                    end
                  end
                end

                context 'when there are multiple unique representative_ids' do
                  before do
                    create(:representative, representative_id: '67890', poa_codes: ['EDF'])
                    create(:representative, representative_id: '54321', poa_codes: ['EDF'])
                  end

                  it 'returns a meaningful 422' do
                    mock_ccg(scopes) do |auth_header|
                      allow(BGS::PowerOfAttorneyVerifier)
                        .to receive(:new)
                        .and_return(OpenStruct.new(current_poa_code: 'EDF'))

                      detail = 'Could not retrieve Power of Attorney due to multiple representatives with code: EDF'

                      get get_poa_path, headers: auth_header

                      response_body = JSON.parse(response.body)['errors'][0]

                      expect(response).to have_http_status(:unprocessable_entity)
                      expect(response_body['title']).to eq('Unprocessable entity')
                      expect(response_body['status']).to eq('422')
                      expect(response_body['detail']).to eq(detail)
                    end
                  end
                end
              end
            end
          end

          context 'when not valid' do
            it 'returns a 401' do
              get get_poa_path, headers: { 'Authorization' => 'Bearer HelloWorld' }

              expect(response.status).to eq(401)
            end
          end
        end
      end
    end

    describe 'status' do
      it 'returns the status of a POA' do
        mock_ccg(scopes) do |auth_header|
          poa = create(:power_of_attorney, auth_headers: auth_header)

          get "#{status_path}/#{poa.id}", params: nil, headers: auth_header
          json = JSON.parse(response.body)

          expect(json['data']['type']).to eq('claims_api_power_of_attorneys')
          expect(json['data']['attributes']['status']).to eq('submitted')
        end
      end

      it 'returns 404 when given an unknown id' do
        mock_ccg(scopes) do |auth_header|
          get "#{status_path}/123456", params: nil, headers: auth_header

          expect(response).to have_http_status(:not_found)
        end
      end
    end

    describe 'appoint_individual' do
      let(:data) do
        {
          data: {
            attributes: {
              representative: {
                poaCode: individual_poa_code,
                firstName: 'my',
                lastName: 'name',
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

      context 'when a POA code isn\'t provided' do
        it 'returns a 422 error code' do
          mock_ccg(scopes) do |auth_header|
            data[:data][:attributes][:representative] = nil

            post appoint_individual_path, params: data.to_json, headers: auth_header
            expect(response.status).to eq(422)
          end
        end
      end

      context 'CCG (Client Credentials Grant) flow' do
        context 'when provided' do
          context 'when valid' do
            it 'returns a 202' do
              mock_ccg(scopes) do |auth_header|
                expect_any_instance_of(local_bgs).to receive(:find_poa_by_participant_id)
                  .and_return(bgs_poa)
                allow_any_instance_of(local_bgs).to receive(:find_poa_history_by_ptcpnt_id)
                  .and_return({ person_poa_history: nil })

                post appoint_individual_path, params: data.to_json, headers: auth_header

                expect(response.status).to eq(202)
              end
            end
          end

          context 'when not valid' do
            it 'returns a 401' do
              post appoint_individual_path, params: data.to_json, headers: { 'Authorization' => 'Bearer HelloWorld' }

              expect(response.status).to eq(401)
            end
          end
        end
      end
    end

    describe 'submit2122' do
      b64_image = File.read('modules/claims_api/spec/fixtures/signature_b64.txt')
      let(:data) do
        {
          data: {
            attributes: {
              serviceOrganization: {
                poaCode: organization_poa_code.to_s
              },
              signatures: {
                veteran: b64_image,
                representative: b64_image
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
                expect_any_instance_of(local_bgs).to receive(:find_poa_by_participant_id)
                  .and_return(bgs_poa)
                allow_any_instance_of(local_bgs).to receive(:find_poa_history_by_ptcpnt_id)
                  .and_return({ person_poa_history: nil })

                post appoint_organization_path, params: data.to_json, headers: auth_header

                expect(response.status).to eq(202)
              end
            end
          end

          context 'when not valid' do
            it 'returns a 401' do
              post appoint_organization_path, params: data, headers: { 'Authorization' => 'Bearer HelloWorld' }

              expect(response.status).to eq(401)
            end
          end
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
                  expect(response_body['detail']).to eq(detail)
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

            context 'when the request data passes schema validation' do
              context 'when no representatives have the provided POA code' do
                let(:request_body) do
                  Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                  'power_of_attorney', '2122', 'invalid_poa.json').read
                end

                it 'returns a meaningful 404' do
                  mock_ccg(%w[claim.write claim.read]) do |auth_header|
                    detail = 'Could not find an Organization with code: aaa'

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
            end
          end
        end

        context 'when not valid' do
          it 'returns a 401' do
            post validate2122_path, headers: { 'Authorization' => 'Bearer HelloWorld' }

            expect(response.status).to eq(401)
          end
        end
      end
    end

    describe 'validate2122a' do
      let(:data) do
        {
          data: {
            attributes: {
              representative: {
                poaCode: individual_poa_code,
                firstName: 'my',
                lastName: 'name',
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
                        detail = 'Could not find an Accredited Representative with code: aaa'

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
                end
              end
            end
          end
        end

        context 'when not valid' do
          it 'returns a 401' do
            post validate2122a_path, headers: { 'Authorization' => 'Bearer HelloWorld' }

            expect(response.status).to eq(401)
          end
        end
      end
    end
  end
end
