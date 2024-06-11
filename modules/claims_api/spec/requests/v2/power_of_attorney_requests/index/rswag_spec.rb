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
        { productionOauth: ['system/claim.read', 'system/system/claim.write'] },
        { sandboxOauth: ['system/claim.read', 'system/system/claim.write'] },
        { bearer_token: [] }
      ]
      produces 'application/json'
      description 'Faceted, paginated, and sorted search of Power of Attorney requests'

      let(:Authorization) { 'Bearer token' }
      let(:scopes) { %w[system/claim.read system/system/claim.write] }

      parameter(
        name: 'query',
        in: :query,
        required: true,
        schema: JSON.parse(
          Rails.root.join(
            'modules',
            'claims_api',
            'config',
            'schemas',
            'v2',
            'request_bodies',
            'power_of_attorney_requests',
            'index',
            'request.json'
          ).read
          # No idea why string keys don't work here.
        ).deep_transform_keys(&:to_sym)
      )

      response '200', 'Search results' do
        schema JSON.parse(Rails.root.join(
          'spec', 'support', 'schemas',
          'claims_api', 'v2', 'power_of_attorney_requests',
          'index', '200.json'
        ).read)

        let(:query) do
          {
            'filter' => {
              'poaCodes' => %w[
                083 002 003 065 074 022 091 070
                097 077 1EY 6B6 862 9U7 BQX
              ],
              'decision' => {
                'statuses' => %w[
                  Accepted
                  Declined
                ]
              }
            },
            'page' => {
              'number' => 2,
              'size' => 5
            },
            'sort' => {
              'field' => 'createdAt',
              'order' => 'asc'
            }
          }
        end

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
        schema JSON.parse(Rails.root.join(
          'spec', 'support', 'schemas',
          'claims_api', 'v2', 'power_of_attorney_requests',
          'index', '422.json'
        ).read)

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
        schema JSON.parse(Rails.root.join(
          'spec', 'support', 'schemas',
          'claims_api', 'v2', 'power_of_attorney_requests',
          'index', '502.json'
        ).read)

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
        schema JSON.parse(Rails.root.join(
          'spec', 'support', 'schemas',
          'claims_api', 'v2', 'power_of_attorney_requests',
          'index', '504.json'
        ).read)

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
        schema JSON.parse(Rails.root.join(
          'spec', 'support', 'schemas',
          'claims_api', 'v2', 'power_of_attorney_requests',
          'index', '401.json'
        ).read)

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
