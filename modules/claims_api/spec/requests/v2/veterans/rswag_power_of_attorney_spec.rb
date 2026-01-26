# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s
require 'rails_helper'
require_relative '../../../rails_helper'
require_relative '../../../support/swagger_shared_components/v2'
require 'bgs_service/claimant_web_service'
require 'bgs_service/org_web_service'
require 'bgs_service/manage_representative_service'

describe 'PowerOfAttorney',
         openapi_spec: Rswag::TextHelpers.new.claims_api_docs do
  let(:org_web_service) { ClaimsApi::OrgWebService }
  let(:claimant_web_service) { ClaimsApi::ClaimantWebService }

  claimant_data = {
    'claimantId' => '1013093331V548481',
    'address' => {
      'addressLine1' => '123 anystreet',
      'city' => 'anytown',
      'stateCode' => 'OR',
      'countryCode' => 'US',
      'zipCode' => '12345'
    },
    'relationship' => 'Spouse'
  }

  path '/veterans/{veteranId}/power-of-attorney' do
    get 'Retrieves current power of attorney' do
      tags 'Power of Attorney'
      operationId 'findPowerOfAttorney'
      security [
        { productionOauth: ['system/claim.read', 'system/claim.write'] },
        { sandboxOauth: ['system/claim.read', 'system/claim.write'] },
        { bearer_token: [] }
      ]
      produces 'application/json'
      description 'Retrieve a claimant’s currently appointed accredited representative with power of attorney ' \
                  '(General POA) for the claimant. Returns empty data if no General POA is assigned.'

      let(:Authorization) { 'Bearer token' }

      parameter name: 'veteranId',
                in: :path,
                required: true,
                type: :string,
                example: '1012667145V762142',
                description: 'ID of claimant'

      let(:veteranId) { '1013062086V794840' } # rubocop:disable RSpec/VariableName
      let(:scopes) { %w[system/claim.read system/claim.write] }
      let(:poa_code) { 'A1Q' }
      let(:bgs_poa) { { person_org_name: "#{poa_code} name-here" } }

      describe 'Getting a successful response' do
        response '200', 'Successful response with a current Power of Attorney' do
          schema JSON.parse(Rails.root.join('spec',
                                            'support',
                                            'schemas',
                                            'claims_api',
                                            'veterans',
                                            'power-of-attorney',
                                            'get.json').read)

          before do |example|
            expect_any_instance_of(claimant_web_service).to receive(:find_poa_by_participant_id).and_return(bgs_poa)
            allow_any_instance_of(org_web_service).to receive(:find_poa_history_by_ptcpnt_id)
              .and_return({ person_poa_history: nil })
            create(:veteran_representative, representative_id: '12345',
                                            poa_codes: [poa_code],
                                            first_name: 'Firstname',
                                            last_name: 'Lastname',
                                            phone: '555-555-5555')
            mock_ccg(scopes) do
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a valid 200 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 401 response' do
        response '401', 'Unauthorized' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'power_of_attorney', 'default.json').read)

          let(:Authorization) { nil }

          before do |example|
            submit_request(example.metadata)
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 401 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 404 response' do
        response '404', 'Resource not found' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'power_of_attorney', 'default.json').read)

          before do |example|
            expect_any_instance_of(claimant_web_service).to receive(:find_poa_by_participant_id).and_return(bgs_poa)
            allow_any_instance_of(org_web_service).to receive(:find_poa_history_by_ptcpnt_id)
              .and_return({ person_poa_history: nil })

            create(:veteran_representative, representative_id: '12345',
                                            poa_codes: ['H1A'],
                                            first_name: 'Firstname',
                                            last_name: 'Lastname',
                                            phone: '555-555-5555')
            mock_ccg(scopes) do
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 404 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 422 response' do
        response '422', 'Unprocessable Entity' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'power_of_attorney', 'default.json').read)

          before do |example|
            expect_any_instance_of(claimant_web_service).to receive(:find_poa_by_participant_id).and_return(bgs_poa)
            allow_any_instance_of(org_web_service).to receive(:find_poa_history_by_ptcpnt_id)
              .and_return({ person_poa_history: nil })
            create(:veteran_representative, representative_id: '12345',
                                            poa_codes: [poa_code],
                                            first_name: 'Firstname',
                                            last_name: 'Lastname',
                                            phone: '555-555-5555')
            create(:veteran_representative, representative_id: '54321',
                                            poa_codes: [poa_code],
                                            first_name: 'Another',
                                            last_name: 'Name',
                                            phone: '222-222-2222')
            mock_ccg(scopes) do
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 422 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end
    end
  end

  path '/veterans/{veteranId}/power-of-attorney-request' do
    post 'Creates power of attorney request for an accredited representative' do
      description 'Request the appointment of an accredited representative, on behalf of a claimant.'
      tags 'Power of Attorney'
      operationId 'postPowerOfAttorneyRequest'
      security [
        { productionOauth: ['system/claim.read', 'system/claim.write'] },
        { sandboxOauth: ['system/claim.read', 'system/claim.write'] },
        { bearer_token: [] }
      ]
      consumes 'application/json'
      produces 'application/json'
      parameter name: 'veteranId',
                in: :path,
                required: true,
                type: :string,
                example: '1012667145V762142',
                description: 'ID of claimant'
      parameter SwaggerSharedComponents::V2.body_examples[:power_of_attorney_request]

      let(:Authorization) { 'Bearer token' }
      let(:veteranId) { '1013062086V794840' } # rubocop:disable RSpec/VariableName
      let(:scopes) { %w[system/claim.write] }
      let(:data) do
        temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                               'power_of_attorney', 'request_representative', 'valid_no_claimant.json').read
        JSON.parse(temp)
      end

      describe 'Getting a successful response' do
        response '201', 'Valid request response' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'veterans',
                                            'power_of_attorney', 'request_representative', 'submit.json').read)

          before do |example|
            allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_v2_poa_requests_skip_bgs).and_return false
            allow_any_instance_of(ClaimsApi::PowerOfAttorneyRequestService::Orchestrator)
              .to receive(:submit_request)
              .and_return({ 'procId' => '12345' })
            create(:veteran_representative, representative_id: '999999999999', poa_codes: ['067'],
                                            first_name: 'Abraham', last_name: 'Lincoln',
                                            user_types: ['veteran_service_officer'])
            create(:veteran_organization, poa: '067', name: 'DISABLED AMERICAN VETERANS')

            mock_ccg(scopes) do
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a valid 201 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 401 response' do
        response '401', 'Unauthorized' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'power_of_attorney', 'default.json').read)

          let(:Authorization) { nil }

          before do |example|
            submit_request(example.metadata)
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 401 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 422 response' do
        response '422', 'Unprocessable Entity' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'power_of_attorney', 'default.json').read)

          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'power_of_attorney', 'request_representative', 'invalid_schema.json').read
            JSON.parse(temp)
          end

          before do |example|
            mock_ccg(scopes) do
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 422 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 404 response' do
        response '404', 'Resource not found' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'power_of_attorney', 'default.json').read)

          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'power_of_attorney', 'request_representative', 'valid_no_claimant.json').read
            JSON.parse(temp)
          end

          before do |example|
            mock_ccg(scopes) do
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 404 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end
    end
  end

  path '/veterans/power-of-attorney-requests' do
    post 'Retrieves power of attorney requests for accredited representatives' do
      tags 'Power of Attorney'
      operationId 'searchPowerOfAttorneyRequests'
      security [
        { productionOauth: ['system/claim.read', 'system/claim.write'] },
        { sandboxOauth: ['system/claim.read', 'system/claim.write'] },
        { bearer_token: [] }
      ]
      produces 'application/json'
      consumes 'application/json'
      description 'Search for power of attorney requests by specified POA codes. Optional filters include searching ' \
                  'by status, city, state, and country.'

      let(:Authorization) { 'Bearer token' }
      let(:scopes) { %w[system/claim.read system/claim.write] }

      body_schema =
        JSON.load_file(
          ClaimsApi::Engine.root.join(
            Settings.claims_api.schema_dir,
            'v2/power_of_attorney_requests/post.json'
          )
        )

      body_example = {
        'data' => {
          'attributes' => {
            'poaCodes' => %w[002 003 083],
            'filter' => {
              'status' => %w[NEW ACCEPTED DECLINED],
              'state' => 'OR',
              'city' => 'Portland',
              'country' => 'USA'
            }
          }
        }
      }

      # No idea why string keys don't work here.
      body_schema.deep_transform_keys!(&:to_sym)
      body_schema[:example] = body_example

      parameter(
        name: 'data', in: :body, required: true,
        schema: body_schema, example: body_example
      )

      parameter(
        name: 'page[size]', in: :query, required: false,
        example: '20', description: 'Number of results to return per page. Max value allowed is 100.'
      )

      parameter(
        name: 'page[number]', in: :query, required: false,
        example: '1', description: 'Number of pages of results to return. Max value allowed is 100.'
      )

      describe 'Getting a 200 response' do
        response '200', 'Search results' do
          schema JSON.load_file(File.expand_path('rswag/index/200.json', __dir__))

          let(:data) { body_example }

          before do |example|
            mock_ccg(scopes) do
              VCR.use_cassette('claims_api/bgs/manage_representative_service/read_poa_request_valid') do
                submit_request(example.metadata)
              end
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 200 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 400 response' do
        response '400', 'Invalid request' do
          schema JSON.load_file(File.expand_path('rswag/index/400.json', __dir__))

          let(:data) do
            {}
          end

          before do |example|
            mock_ccg(scopes) do
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 400 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 401 response' do
        response '401', 'Unauthorized' do
          schema JSON.load_file(File.expand_path('rswag/index/401.json', __dir__))

          let(:data) do
            { 'data' => { 'attributes' => { 'poaCodes' => %w[083] } } }
          end

          before do |example|
            submit_request(example.metadata)
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 401 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end
    end
  end

  path '/veterans/power-of-attorney-requests/{id}' do
    get 'Retrieves a power of attorney request' do
      tags 'Power of Attorney'
      operationId 'getPowerOfAttorneyRequest'
      security [
        { productionOauth: ['system/claim.read', 'system/claim.write'] },
        { sandboxOauth: ['system/claim.read', 'system/claim.write'] },
        { bearer_token: [] }
      ]
      produces 'application/json'
      description 'Retrieve a power of attorney request by id.'

      let(:Authorization) { 'Bearer token' }
      let(:scopes) { %w[system/claim.read system/claim.write] }

      parameter name: 'id',
                in: :path,
                required: true,
                type: :string,
                example: '12e13134-7229-4e44-90ae-bcea2a4525fa',
                description: 'The ID of the Power of Attorney request'

      let(:id) { '12e13134-7229-4e44-90ae-bcea2a4525fa' }
      let(:participant_id) { '600049322' }

      describe 'Getting a 200 response' do
        response '200', 'Successful response with a current Power of Attorney request' do
          schema JSON.load_file(File.expand_path('rswag/show/200.json', __dir__))

          let(:data) { body_example }
          let(:manage_representative_service) { instance_double(ClaimsApi::ManageRepresentativeService) }
          let(:bgs_response) do
            {
              'poaRequestRespondReturnVOList' => { 'VSOUserEmail' => nil, 'VSOUserFirstName' => 'vets-api',
                                                   'VSOUserLastName' => 'vets-api', 'changeAddressAuth' => 'Y',
                                                   'claimantCity' => 'Portland', 'claimantCountry' => 'USA',
                                                   'claimantMilitaryPO' => nil, 'claimantMilitaryPostalCode' => nil,
                                                   'claimantState' => 'OR', 'claimantZip' => '56789',
                                                   'dateRequestActioned' => '2025-01-09T10:19:26-06:00',
                                                   'dateRequestReceived' => '2024-10-30T08:22:07-05:00',
                                                   'declinedReason' => nil, 'healthInfoAuth' => 'Y', 'poaCode' => '074',
                                                   'procID' => '3857362', 'secondaryStatus' => 'Accepted',
                                                   'vetFirstName' => 'ANDREA', 'vetLastName' => 'MITCHELL',
                                                   'vetMiddleName' => 'L', 'vetPtcpntID' => '600049322' },
              'totalNbrOfRecords' => '1'
            }
          end

          before do |example|
            create(:claims_api_power_of_attorney_request, id:,
                                                          proc_id: '3858547',
                                                          veteran_icn: '1012829932V238054',
                                                          poa_code: '003')
            allow_any_instance_of(ClaimsApi::Veteran).to receive(:participant_id).and_return(participant_id)
            allow(ClaimsApi::ManageRepresentativeService).to receive(:new).and_return(manage_representative_service)
            allow(manage_representative_service).to receive(:read_poa_request_by_ptcpnt_id).with(anything)
                                                                                           .and_return(bgs_response)
            mock_ccg(scopes) do
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 200 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 401 response' do
        response '401', 'Unauthorized' do
          schema JSON.load_file(File.expand_path('rswag/show/401.json', __dir__))

          before do |example|
            submit_request(example.metadata)
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 401 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 404 response' do
        response '404', 'Resource not found' do
          schema JSON.load_file(File.expand_path('rswag/show/404.json', __dir__))

          before do |example|
            mock_ccg(scopes) do
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 404 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end
    end
  end

  path '/veterans/power-of-attorney-requests/{id}/decide' do
    post 'Submits representative decision for a power of attorney request' do
      tags 'Power of Attorney'
      operationId 'createPowerOfAttorneyRequestDecisions'
      security [
        { productionOauth: ['system/claim.read', 'system/claim.write'] },
        { sandboxOauth: ['system/claim.read', 'system/claim.write'] },
        { bearer_token: [] }
      ]
      produces 'application/json'
      consumes 'application/json'
      description 'Approve or decline a power of attorney request. If approved, the power of attorney request will ' \
                  'be submitted to VA. The claimant will be notified of the decision by email.'

      parameter name: :id,
                in: :path,
                required: true,
                type: :string,
                example: '348fa995-5b29-4819-91af-13f1bb3c7d77',
                description: 'The ID of the request for representation'

      let(:Authorization) { 'Bearer token' }
      let(:scopes) { %w[system/claim.read system/claim.write] }
      let(:id) { '348fa995-5b29-4819-91af-13f1bb3c7d77' }
      let(:new_record_id) { '5ff6a995-5b29-4819-91af-13f1bb312fg5' }

      body_schema =
        JSON.load_file(
          ClaimsApi::Engine.root.join(
            Settings.claims_api.schema_dir,
            'v2/power_of_attorney_requests/param/decision/post.json'
          )
        )

      # No idea why string keys don't work here.
      body_schema.deep_transform_keys!(&:to_sym)
      body_schema[:example] = {
        'data' => {
          'attributes' => {
            'decision' => 'ACCEPTED',
            'representativeId' => '12345678',
            'declinedReason' => nil
          }
        }
      }

      parameter name: 'data', in: :body, required: true, schema: body_schema

      describe 'Getting a 200 response' do
        response '200', 'Submit decision' do
          schema JSON.load_file(File.expand_path('rswag/create/200.json', __dir__))

          let(:data) { body_schema[:example] }
          let(:poa_request_service) { instance_double(ClaimsApi::PowerOfAttorneyRequestService::Decide) }
          let(:get_poa_request_response) do
            {
              'VSOUserEmail' => nil, 'VSOUserFirstName' => 'vets-api',
              'VSOUserLastName' => 'vets-api', 'changeAddressAuth' => 'Y',
              'claimantCity' => 'Portland', 'claimantCountry' => 'USA',
              'claimantMilitaryPO' => nil, 'claimantMilitaryPostalCode' => nil,
              'claimantState' => 'OR', 'claimantZip' => '56789',
              'dateRequestActioned' => '2025-01-09T10:19:26-06:00',
              'dateRequestReceived' => '2024-10-30T08:22:07-05:00',
              'declinedReason' => nil, 'healthInfoAuth' => 'Y', 'poaCode' => '074',
              'procID' => '3857362', 'secondaryStatus' => 'Accepted',
              'vetFirstName' => 'ANDREA', 'vetLastName' => 'MITCHELL',
              'vetMiddleName' => 'L', 'vetPtcpntID' => '600049322',
              'id' => new_record_id
            }
          end

          before do |example|
            create(:claims_api_power_of_attorney_request, id:,
                                                          proc_id: '3857362',
                                                          veteran_icn: '1012829932V238054',
                                                          poa_code: '003')
            allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_v2_poa_requests_skip_bgs).and_return(false)
            allow_any_instance_of(ClaimsApi::V2::Veterans::PowerOfAttorney::BaseController).to receive(:fetch_ptcpnt_id)
              .with(anything).and_return('600049322')
            allow(ClaimsApi::PowerOfAttorneyRequestService::Decide).to receive(:new).and_return(poa_request_service)
            allow(poa_request_service).to receive(:handle_poa_response).and_return(get_poa_request_response)
            allow_any_instance_of(ClaimsApi::V2::Veterans::PowerOfAttorney::RequestController)
              .to receive(:process_poa_decision).and_return(OpenStruct.new(id: '1234'))
            allow(poa_request_service).to receive(
              :validate_decide_representative_params!
            ).with(anything, anything).and_return(nil)
            allow(poa_request_service).to receive(
              :build_veteran_and_dependent_data
            ).with(anything, anything).and_return(nil)

            mock_ccg(scopes) do
              VCR.use_cassette('claims_api/bgs/manage_representative_service/update_poa_request_accepted') do
                submit_request(example.metadata)
              end
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 200 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 404 response' do
        response '404', 'Resource not found' do
          schema JSON.load_file(File.expand_path('rswag/create/404.json', __dir__))

          let(:data) do
            {
              'data' => {
                'attributes' => {
                  'decision' => 'DECLINED',
                  'declinedReason' => 'RSWAG POA test reason',
                  'representativeId' => '918273645463'
                }
              }
            }
          end

          before do |example|
            allow(ClaimsApi::PowerOfAttorneyRequest).to(
              receive(:find_by).and_return(nil)
            )
            mock_ccg(scopes) do
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
            examples = example.metadata.dig(:response, :content, 'application/json', :example)
            examples[:schema_validation_error] = {
              summary: 'Schema validation error',
              value: JSON.parse(response.body, symbolize_names: true)
            }
          end

          it 'returns a 404 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 422 response' do
        response '422', 'Malformed request body' do
          schema JSON.load_file(File.expand_path('rswag/create/422.json', __dir__))

          # Depends on `rswag-specs` internals.
          let(:data) { OpenStruct.new(to_json: '{{{{') }

          before do |example|
            mock_ccg(scopes) do
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 422 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 401 response' do
        response '401', 'Unauthorized' do
          schema JSON.load_file(File.expand_path('rswag/create/401.json', __dir__))

          let(:data) { body_schema[:example] }

          before do |example|
            submit_request(example.metadata)
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 401 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end
    end
  end

  path '/veterans/{veteranId}/2122/validate' do
    post 'Validates request to establish an organization as a claimant’s accredited representative' do
      tags 'Power of Attorney'
      operationId 'post2122Validate'
      security [
        { productionOauth: ['system/claim.read', 'system/claim.write'] },
        { sandboxOauth: ['system/claim.read', 'system/claim.write'] },
        { bearer_token: [] }
      ]
      consumes 'application/json'
      produces 'application/json'
      parameter name: 'veteranId',
                in: :path,
                required: true,
                type: :string,
                example: '1012667145V762142',
                description: 'ID of claimant'
      parameter SwaggerSharedComponents::V2.body_examples[:power_of_attorney2122]

      let(:veteranId) { '1013062086V794840' } # rubocop:disable RSpec/VariableName
      let(:Authorization) { 'Bearer token' }
      let(:scopes) { %w[system/claim.read system/claim.write] }

      pdf_description = <<~VERBIAGE
        Validate a request to establish an organization with power of attorney (VA Form 21-22). Use POST
        /veterans/{veteranId}/2122 to automatically establish submit VA Form 21-22.
      VERBIAGE

      description pdf_description

      describe 'Getting a successful response' do
        response '200', 'Valid request response' do
          let(:poa_code) { '083' }

          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'veterans',
                                            'power_of_attorney', '2122', 'validate.json').read)
          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'power_of_attorney', '2122', 'valid.json').read
            JSON.parse(temp)
          end

          before do |example|
            create(:veteran_organization, poa: poa_code)
            create(:veteran_representative, representative_id: '999999999999', poa_codes: [poa_code])

            mock_ccg(scopes) do
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a valid 200 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 401 response' do
        response '401', 'Unauthorized' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'power_of_attorney', 'default.json').read)

          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'power_of_attorney', '2122', 'valid.json').read
            JSON.parse(temp)
          end

          let(:Authorization) { nil }

          before do |example|
            submit_request(example.metadata)
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 401 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 422 response' do
        response '422', 'Unprocessable Entity' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'power_of_attorney', 'default.json').read)

          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'power_of_attorney', '2122', 'invalid_schema.json').read
            JSON.parse(temp)
          end

          before do |example|
            mock_ccg(scopes) do
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 422 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 404 response' do
        response '404', 'Resource not found' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'power_of_attorney', 'default.json').read)

          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'power_of_attorney', '2122', 'valid.json').read
            JSON.parse(temp)
          end

          before do |example|
            mock_ccg(scopes) do
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 404 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end
    end
  end

  path '/veterans/{veteranId}/2122' do
    post 'Automatically establishes an organization as a claimant’s accredited representative (VA Form 21-22)' do
      post_description = <<~VERBIAGE
        Submit VA Form 21-22 to automatically establish a VA accredited organization with power of attorney
        (General POA).
      VERBIAGE
      description post_description
      tags 'Power of Attorney'
      operationId 'post2122'
      security [
        { productionOauth: ['system/claim.read', 'system/claim.write'] },
        { sandboxOauth: ['system/claim.read', 'system/claim.write'] },
        { bearer_token: [] }
      ]
      consumes 'application/json'
      produces 'application/json'
      parameter name: 'veteranId',
                in: :path,
                required: true,
                type: :string,
                example: '1012667145V762142',
                description: 'ID of claimant'
      parameter SwaggerSharedComponents::V2.body_examples[:power_of_attorney2122]

      let(:Authorization) { 'Bearer token' }
      let(:veteranId) { '1013062086V794840' } # rubocop:disable RSpec/VariableName
      let(:scopes) { %w[system/claim.write] }
      let(:organization_poa_code) { '083' }
      let(:bgs_poa) { { person_org_name: "#{organization_poa_code} name-here" } }

      request_template = JSON.parse(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                                    'power_of_attorney', '2122', 'valid.json').read)

      request_template_with_dependent = JSON.parse(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2',
                                                                   'veterans', 'power_of_attorney', '2122',
                                                                   'valid.json').read)

      request_template_with_dependent['data']['attributes']['claimant'] = claimant_data

      parameter name: :power_of_attorney_request, in: :body,
                schema: SwaggerSharedComponents::V2.body_examples[:power_of_attorney_2122a][:schema]

      parameter in: :body, examples: {
        'POA for Veteran' => {
          value: request_template
        },
        'POA for Dependent Claimant' => {
          value: request_template_with_dependent
        }
      }

      let(:data) do
        temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                               'power_of_attorney', '2122', 'valid.json').read
        JSON.parse(temp)
      end

      describe 'Getting a successful response' do
        response '202', 'Valid request response' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'veterans',
                                            'power_of_attorney', '2122', 'submit.json').read)

          before do |example|
            allow_any_instance_of(claimant_web_service).to receive(:find_poa_by_participant_id).and_return(bgs_poa)
            allow_any_instance_of(org_web_service).to receive(:find_poa_history_by_ptcpnt_id)
              .and_return({ person_poa_history: nil })
            create(:veteran_organization, poa: organization_poa_code,
                                          name: "#{organization_poa_code} - DISABLED AMERICAN VETERANS",
                                          phone: '555-555-5555')
            create(:veteran_representative, representative_id: '999999999999',
                                            poa_codes: [organization_poa_code], phone: '555-555-5555')
            mock_file_number_check

            mock_ccg(scopes) do
              submit_request(example.metadata)
            end
          end

          let(:power_of_attorney_request) do
            data
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a valid 202 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 401 response' do
        response '401', 'Unauthorized' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'power_of_attorney', 'default.json').read)

          let(:Authorization) { nil }

          before do |example|
            submit_request(example.metadata)
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 401 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 422 response' do
        response '422', 'Unprocessable Entity' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'power_of_attorney', 'default.json').read)

          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'power_of_attorney', '2122', 'invalid_schema.json').read
            JSON.parse(temp)
          end

          before do |example|
            mock_ccg(scopes) do
              allow_any_instance_of(org_web_service).to receive(:find_poa_history_by_ptcpnt_id)
                .and_return({ person_poa_history: nil })
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 422 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 404 response' do
        response '404', 'Resource not found' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'power_of_attorney', 'default.json').read)

          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'power_of_attorney', '2122', 'valid.json').read
            JSON.parse(temp)
          end

          before do |example|
            mock_ccg(scopes) do
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 404 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end
    end
  end

  path '/veterans/{veteranId}/2122a/validate' do
    post 'Validates request to establish an individual as a claimant’s accredited representative (VA Form 21-22a)' do
      tags 'Power of Attorney'
      operationId 'post2122aValidate'
      security [
        { productionOauth: ['system/claim.read', 'system/claim.write'] },
        { sandboxOauth: ['system/claim.read', 'system/claim.write'] },
        { bearer_token: [] }
      ]
      consumes 'application/json'
      produces 'application/json'
      let(:scopes) { %w[system/claim.read system/claim.write] }

      parameter name: 'veteranId',
                in: :path,
                required: true,
                type: :string,
                example: '1012667145V762142',
                description: 'ID of claimant'

      let(:veteranId) { '1013062086V794840' } # rubocop:disable RSpec/VariableName
      let(:Authorization) { 'Bearer token' }
      parameter SwaggerSharedComponents::V2.body_examples[:power_of_attorney_2122a]
      pdf_description = <<~VERBIAGE
        Validate a request to establish an individual with power of attorney (VA Form 21-22a). Use POST
        /veterans/{veteranId}/2122a to automatically establish submit VA Form 21-22a.
      VERBIAGE

      description pdf_description

      describe 'Getting a successful response' do
        response '200', 'Valid request response' do
          let(:poa_code) { '067' }

          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'veterans',
                                            'power_of_attorney', '2122a', 'validate.json').read)
          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'power_of_attorney', '2122a', 'valid.json').read
            temp = JSON.parse(temp)

            temp
          end

          before do |example|
            create(:veteran_representative, representative_id: '999999999999',
                                            poa_codes: [poa_code],
                                            first_name: 'Firstname',
                                            last_name: 'Lastname',
                                            phone: '555-555-5555')

            mock_ccg(scopes) do
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a valid 200 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 401 response' do
        response '401', 'Unauthorized' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'power_of_attorney', 'default.json').read)

          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'power_of_attorney', '2122a', 'valid.json').read
            temp = JSON.parse(temp)

            temp
          end

          let(:Authorization) { nil }

          before do |example|
            submit_request(example.metadata)
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 401 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 422 response' do
        response '422', 'Unprocessable Entity' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'power_of_attorney', 'default.json').read)

          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'power_of_attorney', '2122a', 'invalid_schema.json').read
            temp = JSON.parse(temp)

            temp
          end

          before do |example|
            mock_ccg(scopes) do
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 422 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 404 response' do
        response '404', 'Resource not found' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'power_of_attorney', 'default.json').read)

          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'power_of_attorney', '2122a', 'valid.json').read
            temp = JSON.parse(temp)

            temp
          end

          before do |example|
            mock_ccg(scopes) do
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 404 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end
    end
  end

  path '/veterans/{veteranId}/2122a' do
    post 'Automatically establishes an individual as a claimant’s accredited representative (VA Form 21-22a)' do
      tags 'Power of Attorney'
      operationId 'post2122a'
      security [
        { productionOauth: ['system/claim.read', 'system/claim.write'] },
        { sandboxOauth: ['system/claim.read', 'system/claim.write'] },
        { bearer_token: [] }
      ]
      consumes 'application/json'
      produces 'application/json'

      parameter name: 'veteranId',
                in: :path,
                required: true,
                type: :string,
                example: '1012667145V762142',
                description: 'ID of claimant'

      let(:veteranId) { '1013062086V794840' } # rubocop:disable RSpec/VariableName
      let(:Authorization) { 'Bearer token' }
      parameter SwaggerSharedComponents::V2.body_examples[:power_of_attorney_2122a]
      post_description = <<~VERBIAGE
        Submit VA Form 21-22 to automatically establish a VA accredited individual with power of attorney (General POA).
      VERBIAGE
      description post_description
      let(:scopes) { %w[system/claim.read system/claim.write] }
      let(:poa_code) { '067' }
      let(:bgs_poa) { { person_org_name: "#{poa_code} name-here" } }

      request_template = JSON.parse(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                                    'power_of_attorney', '2122a', 'valid.json').read)

      request_template_with_dependent = JSON.parse(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2',
                                                                   'veterans', 'power_of_attorney', '2122a',
                                                                   'valid.json').read)

      request_template_with_dependent['data']['attributes']['claimant'] = claimant_data

      parameter name: :power_of_attorney_request, in: :body,
                schema: SwaggerSharedComponents::V2.body_examples[:power_of_attorney_2122a][:schema]

      parameter in: :body, examples: {
        'POA for Veteran' => {
          value: request_template
        },
        'POA for Dependent Claimant' => {
          value: request_template_with_dependent
        }
      }

      describe 'Getting a successful response' do
        response '202', 'Valid request response' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'veterans',
                                            'power_of_attorney', '2122a', 'submit.json').read)
          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'power_of_attorney', '2122a', 'valid.json').read
            temp = JSON.parse(temp)

            temp
          end

          let(:power_of_attorney_request) do
            data
          end

          before do |example|
            allow_any_instance_of(claimant_web_service).to receive(:find_poa_by_participant_id).and_return(bgs_poa)
            allow_any_instance_of(org_web_service).to receive(:find_poa_history_by_ptcpnt_id)
              .and_return({ person_poa_history: nil })
            create(:veteran_representative, representative_id: '999999999999',
                                            poa_codes: [poa_code],
                                            first_name: 'Firstname',
                                            last_name: 'Lastname',
                                            phone: '555-555-5555')
            mock_file_number_check

            mock_ccg(scopes) do
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a valid 202 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 401 response' do
        response '401', 'Unauthorized' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'power_of_attorney', 'default.json').read)

          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'power_of_attorney', '2122a', 'valid.json').read
            temp = JSON.parse(temp)

            temp
          end

          let(:Authorization) { nil }

          before do |example|
            submit_request(example.metadata)
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 401 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 422 response' do
        response '422', 'Unprocessable Entity' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'power_of_attorney', 'default.json').read)

          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'power_of_attorney', '2122a', 'invalid_schema.json').read
            temp = JSON.parse(temp)

            temp
          end

          before do |example|
            mock_ccg(scopes) do
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 422 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 404 response' do
        response '404', 'Resource not found' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'power_of_attorney', 'default.json').read)

          let(:data) do
            temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                                   'power_of_attorney', '2122a', 'valid.json').read
            temp = JSON.parse(temp)

            temp
          end

          before do |example|
            mock_ccg(scopes) do
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 404 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end
    end
  end

  path '/veterans/{veteranId}/power-of-attorney/{id}' do
    get 'Checks status of power of attorney submission (VA Forms 21-22 or 21-22a)' do
      description 'Check the submissions status of a request to appoint power of attorney (VA Forms 21-22 or 21-22a).'
      tags 'Power of Attorney'
      operationId 'getPowerOfAttorneyStatus'
      security [
        { productionOauth: ['system/claim.read', 'system/claim.write'] },
        { sandboxOauth: ['system/claim.read', 'system/claim.write'] },
        { bearer_token: [] }
      ]
      produces 'application/json'
      parameter name: 'veteranId',
                in: :path,
                required: true,
                type: :string,
                example: '1012667145V762142',
                description: 'ID of claimant'
      parameter name: 'id',
                in: :path,
                required: true,
                type: :string,
                example: '12e13134-7229-4e44-90ae-bcea2a4525fa',
                description: 'The ID of the 21-22 submission'

      let(:veteranId) { '1013062086V794840' } # rubocop:disable RSpec/VariableName
      let(:Authorization) { 'Bearer token' }
      let(:scopes) { %w[system/claim.read system/claim.write] }
      let(:poa) { create(:power_of_attorney, :pending) }
      let(:id) { poa.id }

      describe 'Getting a successful response' do
        response '200', 'Valid request response' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2',
                                            'veterans', 'power_of_attorney', 'status.json').read)

          before do |example|
            mock_ccg(scopes) do
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a valid 200 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 401 response' do
        response '401', 'Unauthorized' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'power_of_attorney', 'default.json').read)

          let(:Authorization) { nil }

          before do |example|
            submit_request(example.metadata)
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 401 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end

      describe 'Getting a 404 response' do
        response '404', 'Resource not found' do
          schema JSON.parse(Rails.root.join('spec', 'support', 'schemas', 'claims_api', 'v2', 'errors',
                                            'power_of_attorney', 'default.json').read)

          let(:id) { -1 }
          before do |example|
            mock_ccg(scopes) do
              submit_request(example.metadata)
            end
          end

          after do |example|
            example.metadata[:response][:content] = {
              'application/json' => {
                example: JSON.parse(response.body, symbolize_names: true)
              }
            }
          end

          it 'returns a 404 response' do |example|
            assert_response_matches_metadata(example.metadata)
          end
        end
      end
    end
  end
end
