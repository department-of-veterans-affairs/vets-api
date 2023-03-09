# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

# rubocop:disable RSpec/VariableName, Layout/LineLength
describe 'Appeals Status', swagger_doc: DocHelpers.output_json_path, type: :request do
  include DocHelpers
  if DocHelpers.decision_reviews?
    let(:apikey) { 'apikey' }
  else
    let(:Authorization) { 'Bearer TEST_TOKEN' }
  end

  if DocHelpers.running_rake_task?
    path '/appeals' do
      get 'Retrieve appeals status for the Veteran with the supplied SSN' do
        scopes = AppealsApi::V1::AppealsController::OAUTH_SCOPES[:GET]
        tags 'Appeals Status'
        operationId 'getAppealStatus'

        description "Returns a list of all known appeal records for the given veteran. Includes details of each appeal's current status, priority, and history of updates."

        security DocHelpers.security_config(scopes)
        consumes 'application/json'
        produces 'application/json'

        parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_ssn_header]

        parameter name: 'X-VA-User',
                  in: :header,
                  required: true,
                  example: 'va.api.user+idme.001@gmail.com',
                  schema: { type: 'string' },
                  description: 'VA username of the person making the request'

        let(:'X-VA-SSN') { '796130115' }
        let(:'X-VA-User') { 'va.api.user+idme.001@gmail.com' }

        response '200', 'Appeals retrieved successfully' do
          response_schema = {
            type: 'object',
            properties: {
              data: {
                '$ref': '#/components/schemas/appeals'
              }
            },
            required: ['data']
          }
          schema response_schema

          context 'with successful caseflow response' do
            before do |example|
              VCR.use_cassette('caseflow/appeals') do
                with_rswag_auth(scopes) do
                  submit_request(example.metadata)
                end
              end
            end

            it 'returns a 200 response' do |example|
              assert_response_matches_metadata(example.metadata)
            end
          end
        end

        response '400', 'Missing SSN header' do
          let(:'X-VA-SSN') { nil }

          schema '$ref' => '#/components/schemas/errorModel'

          context 'with successful caseflow response' do
            before do |example|
              VCR.use_cassette('caseflow/appeals') do
                with_rswag_auth(scopes) do
                  submit_request(example.metadata)
                end
              end
            end

            it 'returns a 400 response' do |example|
              assert_response_matches_metadata(example.metadata)
            end
          end
        end

        response '422', 'Invalid SSN' do
          schema '$ref' => '#/components/schemas/errorModel'

          context 'with caseflow error response' do
            before do |example|
              VCR.use_cassette('caseflow/invalid_ssn') do
                with_rswag_auth(scopes) do
                  submit_request(example.metadata)
                end
              end
            end

            it 'returns a 422 response' do |example|
              pending('FIXME: Raw caseflow error is currently returned; Error should be reformatted according to the shared errorModel schema.')
              assert_response_matches_metadata(example.metadata)
            end
          end
        end

        it_behaves_like 'rswag 500 response'
      end
    end
  end
end
# rubocop:enable RSpec/VariableName, Layout/LineLength
