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
  path '/power-of-attorney-requests' do
    get 'Search for Power of Attorney requests.' do
      tags 'Power of Attorney'
      operationId 'searchPowerOfAttorneyRequests'
      security [
        { productionOauth: ['system/claim.read', 'system/claim.write'] },
        { sandboxOauth: ['system/claim.read', 'system/claim.write'] },
        { bearer_token: [] }
      ]
      produces 'application/json'
      description 'Faceted, paginated, and sorted search of Power of Attorney requests'

      let(:Authorization) { 'Bearer token' }
      let(:scopes) { %w[system/claim.read system/claim.write] }

      query_schema =
        JSON.load_file(
          ClaimsApi::Engine.root.join(
            Settings.claims_api.schema_dir,
            'v2/power_of_attorney_requests/get.json'
          )
        )

      query_example = {
        'filter' => {
          'poaCodes' => %w[
            083 002 003 065 074 022 091 070
            097 077 1EY 6B6 862 9U7 BQX
          ],
          'decision' => {
            'statuses' => %w[
              none
              accepting
              declining
            ]
          }
        },
        'page' => {
          'number' => 2,
          'size' => 3
        },
        'sort' => {
          'field' => 'createdAt',
          'order' => 'asc'
        }
      }

      # No idea why string keys don't work here.
      query_schema.deep_transform_keys!(&:to_sym)
      query_schema[:example] = query_example

      parameter(
        name: 'query', in: :query, required: true,
        schema: query_schema, example: query_example
      )

      response '200', 'Search results' do
        schema JSON.load_file(File.expand_path('rswag/200.json', __dir__))

        let(:query) { query_example }

        before do |example|
          mock_ccg(scopes) do
            use_soap_cassette('nonempty', use_spec_name_prefix: true) do
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

      response '422', 'Invalid query' do
        schema JSON.load_file(File.expand_path('rswag/422.json', __dir__))

        let(:query) do
          {
            'filter' => {
              'decision' => {
                'statuses' => [
                  'NotAStatus'
                ]
              }
            },
            'sort' => {
              'field' => nil,
              'order' => nil
            },
            'page' => {
              'size' => 'whoops',
              'number' => nil
            }
          }
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

      response '502', 'Bad gateway' do
        schema JSON.load_file(File.expand_path('rswag/502.json', __dir__))

        let(:query) do
          { 'filter' => { 'poaCodes' => %w[083] } }
        end

        before do |example|
          pattern = %r{/VDC/ManageRepresentativeService}
          stub_request(:post, pattern).to_raise(
            Faraday::ConnectionFailed
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
        end

        it do |example|
          assert_response_matches_metadata(example.metadata)
        end
      end

      response '504', 'Gateway timeout' do
        schema JSON.load_file(File.expand_path('rswag/504.json', __dir__))

        let(:query) do
          { 'filter' => { 'poaCodes' => %w[083] } }
        end

        before do |example|
          pattern = %r{/VDC/ManageRepresentativeService}
          stub_request(:post, pattern).to_raise(
            Faraday::TimeoutError
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
        end

        it do |example|
          assert_response_matches_metadata(example.metadata)
        end
      end

      response '401', 'Unauthorized' do
        schema JSON.load_file(File.expand_path('rswag/401.json', __dir__))

        let(:query) do
          { 'filter' => { 'poaCodes' => %w[083] } }
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
