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
  path '/power-of-attorney-requests/{id}/decision' do
    post 'Create the decision for Power of Attorney requests.' do
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
          'type' => 'powerOfAttorneyRequestDecision',
          'attributes' => {
            'status' => 'accepting',
            'decliningReason' => nil,
            'createdBy' => {
              'firstName' => 'BEATRICE',
              'lastName' => 'STROUD',
              'email' => 'Beatrice.Stroud44@va.gov'
            }
          }
        }
      }

      parameter name: :id, in: :path, type: :string
      parameter name: 'data', in: :body, required: true, schema: body_schema

      response '202', 'Create decision' do
        let(:id) { '600082980_3848768' }
        let(:data) { body_schema[:example] }

        before do |example|
          allow(ClaimsApi::PowerOfAttorneyRequestService::UpdatePowerOfAttorney).to(
            receive(:perform)
          )

          mock_ccg(scopes) do
            use_soap_cassette('declined', use_spec_name_prefix: true) do
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

      response '404', 'Not found' do
        schema JSON.load_file(File.expand_path('rswag/404.json', __dir__))

        let(:id) { '1234_5678' }
        let(:data) { body_schema[:example] }

        before do |example|
          mock_ccg(scopes) do
            use_soap_cassette('nonexistent_id', use_spec_name_prefix: true) do
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

      response '422', 'Invalid request' do
        schema JSON.load_file(File.expand_path('rswag/422.json', __dir__))

        let(:id) { '600043198_12072' }
        let(:data) do
          {
            'data' => {
              'type' => 'powerOfAttorneyRequestDecision',
              'attributes' => {
                'createdBy' => {
                  'firstName' => 'BEATRICE',
                  'lastName' => 'STROUD',
                  'email' => 'Beatrice.Stroud44@va.gov'
                }
              }
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

      response '422', 'Invalid request' do
        schema JSON.load_file(File.expand_path('rswag/422.json', __dir__))

        let(:id) { '600043198_12072' }
        let(:data) { body_schema[:example] }

        before do |example|
          mock_ccg(scopes) do
            use_soap_cassette('invalid_recreation', use_spec_name_prefix: true) do
              submit_request(example.metadata)
            end
          end
        end

        after do |example|
          example.metadata[:response][:content] ||= { 'application/json' => { examples: {} } }
          examples = example.metadata.dig(:response, :content, 'application/json', :examples)
          examples[:invalid_recreation_error] = {
            summary: 'Invalid recreation error',
            value: JSON.parse(response.body, symbolize_names: true)
          }
        end

        it do |example|
          assert_response_matches_metadata(example.metadata)
        end
      end

      response '422', 'Invalid request' do
        schema JSON.load_file(File.expand_path('rswag/422.json', __dir__))

        let(:id) { '600036513_15839' }
        let(:data) { body_schema[:example] }

        before do |example|
          mock_ccg(scopes) do
            use_soap_cassette('obsolete', use_spec_name_prefix: true) do
              submit_request(example.metadata)
            end
          end
        end

        after do |example|
          example.metadata[:response][:content] ||= { 'application/json' => { examples: {} } }
          examples = example.metadata.dig(:response, :content, 'application/json', :examples)
          examples[:obsolete_error] = {
            summary: 'Obsolete Power Of Attorney request',
            value: JSON.parse(response.body, symbolize_names: true)
          }
        end

        it do |example|
          assert_response_matches_metadata(example.metadata)
        end
      end

      response '400', 'Malformed request body' do
        schema JSON.load_file(File.expand_path('rswag/400.json', __dir__))

        let(:id) { '600043198_12072' }
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

      response '502', 'Bad gateway' do
        schema JSON.load_file(File.expand_path('rswag/502.json', __dir__))

        let(:id) { '600043198_12072' }
        let(:data) { body_schema[:example] }

        before do |example|
          pattern = %r{/VDC/VeteranRepresentativeService}
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

        let(:id) { '600043198_12072' }
        let(:data) { body_schema[:example] }

        before do |example|
          pattern = %r{/VDC/VeteranRepresentativeService}
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

        let(:id) { '600043198_12072' }
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
