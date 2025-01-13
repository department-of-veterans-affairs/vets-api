# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s
require 'rails_helper'
require Rails.root / 'modules/claims_api/spec/rails_helper'
require Rails.root / 'modules/claims_api/lib/bgs_service/manage_representative_service'

metadata = {
  openapi_spec: Rswag::TextHelpers.new.claims_api_docs,
  production: false,
  bgs: true
}

# rubocop:disable RSpec/ScatteredSetup, RSpec/RepeatedExample
describe 'PowerOfAttorney', metadata do
  path '/veterans/power-of-attorney-requests/{id}' do
    get 'Retrieves a Power of Attorney request' do
      tags 'Power of Attorney'
      operationId 'getPowerOfAttorneyRequest'
      security [
        { productionOauth: ['system/claim.read', 'system/claim.write'] },
        { sandboxOauth: ['system/claim.read', 'system/claim.write'] },
        { bearer_token: [] }
      ]
      produces 'application/json'
      description 'Retrieves a Power of Attorney request.'

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

      response '200', 'Successful response with a current Power of Attorney request' do
        schema JSON.load_file(File.expand_path('rswag/200.json', __dir__))

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
          FactoryBot.create(:claims_api_power_of_attorney_request, id:,
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

        it do |example|
          assert_response_matches_metadata(example.metadata)
        end
      end

      response '401', 'Unauthorized' do
        schema JSON.load_file(File.expand_path('rswag/401.json', __dir__))

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

        it do |example|
          assert_response_matches_metadata(example.metadata)
        end
      end

      response '404', 'Resource not found' do
        schema JSON.load_file(File.expand_path('rswag/404.json', __dir__))

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

        it do |example|
          assert_response_matches_metadata(example.metadata)
        end
      end
    end
  end
end
# rubocop:enable RSpec/ScatteredSetup, RSpec/RepeatedExample
