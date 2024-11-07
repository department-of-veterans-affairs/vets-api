# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s
require 'rails_helper'
require Rails.root / 'modules/claims_api/spec/rails_helper'

metadata = {
  openapi_spec: Rswag::TextHelpers.new.claims_api_docs,
  production: false,
  bgs: true
}

# rubocop:disable RSpec/ScatteredSetup, RSpec/RepeatedExample
describe 'PowerOfAttorney', metadata do
  path '/veterans/power-of-attorney-requests' do
    post 'Search for Power of Attorney requests.' do
      tags 'Power of Attorney'
      operationId 'searchPowerOfAttorneyRequests'
      security [
        { productionOauth: ['system/claim.read', 'system/claim.write'] },
        { sandboxOauth: ['system/claim.read', 'system/claim.write'] },
        { bearer_token: [] }
      ]
      produces 'application/json'
      consumes 'application/json'
      description 'Search for Power of Attorney requests'

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
            'poaCodes' => %w[002 003 083]
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

      response '200', 'Search results' do
        schema JSON.load_file(File.expand_path('rswag/200.json', __dir__))

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

        it do |example|
          assert_response_matches_metadata(example.metadata)
        end
      end

      response '400', 'Invalid request' do
        schema JSON.load_file(File.expand_path('rswag/400.json', __dir__))

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

        it do |example|
          assert_response_matches_metadata(example.metadata)
        end
      end

      response '401', 'Unauthorized' do
        schema JSON.load_file(File.expand_path('rswag/401.json', __dir__))

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

        it do |example|
          assert_response_matches_metadata(example.metadata)
        end
      end
    end
  end
end
# rubocop:enable RSpec/ScatteredSetup, RSpec/RepeatedExample
