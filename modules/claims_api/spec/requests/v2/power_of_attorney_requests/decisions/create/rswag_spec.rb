# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s
require 'rails_helper'
require Rails.root / 'modules/claims_api/spec/rails_helper'

metadata = {
  openapi_spec: Rswag::TextHelpers.new.claims_api_docs,
  production: false,
  bgs: true,
  run_at: '2024-06-13T19:31:03Z'
}

# rubocop:disable RSpec/ScatteredSetup, RSpec/RepeatedExample
describe 'PowerOfAttorney', metadata do
  path '/veterans/power-of-attorney-requests/decide' do
    post 'Submit the decision for Power of Attorney requests.' do
      tags 'Power of Attorney'
      operationId 'createPowerOfAttorneyRequestDecisions'
      security [
        { productionOauth: ['system/claim.read', 'system/claim.write'] },
        { sandboxOauth: ['system/claim.read', 'system/claim.write'] },
        { bearer_token: [] }
      ]
      produces 'application/json'
      consumes 'application/json'
      description 'Create the decision for Power of Attorney requests'

      let(:Authorization) { 'Bearer token' }
      let(:scopes) { %w[system/claim.read system/claim.write] }

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
            'procId' => '76529',
            'decision' => 'accepted',
            'declinedReason' => nil
          }
        }
      }

      parameter name: 'data', in: :body, required: true, schema: body_schema

      response '200', 'Submit decision' do
        schema JSON.load_file(File.expand_path('rswag/200.json', __dir__))

        let(:data) { body_schema[:example] }

        before do |example|
          allow(ClaimsApi::PowerOfAttorneyRequestService::UpdatePowerOfAttorney).to(
            receive(:perform)
          )

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

        it do |example|
          assert_response_matches_metadata(example.metadata)
        end
      end

      response '400', 'Invalid request' do
        schema JSON.load_file(File.expand_path('rswag/400.json', __dir__))

        let(:data) do
          {
            'data' => {
              'attributes' => {}
            }
          }
        end

        before do |example|
          mock_ccg(scopes) do
            submit_request(example.metadata)
          end
        end

        after do |example|
          example.metadata[:response][:content] ||= { 'application/json' => { examples: {} } }
          examples = example.metadata.dig(:response, :content, 'application/json', :examples)
          examples[:schema_validation_error] = {
            summary: 'Schema validation error',
            value: JSON.parse(response.body, symbolize_names: true)
          }
        end

        it do |example|
          assert_response_matches_metadata(example.metadata)
        end
      end

      response '422', 'Malformed request body' do
        schema JSON.load_file(File.expand_path('rswag/422.json', __dir__))

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

        it do |example|
          assert_response_matches_metadata(example.metadata)
        end
      end

      response '401', 'Unauthorized' do
        schema JSON.load_file(File.expand_path('rswag/401.json', __dir__))

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

        it do |example|
          assert_response_matches_metadata(example.metadata)
        end
      end
    end
  end
end
# rubocop:enable RSpec/ScatteredSetup, RSpec/RepeatedExample
