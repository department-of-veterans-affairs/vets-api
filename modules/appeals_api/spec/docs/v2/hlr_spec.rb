# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s

require 'rails_helper'
require_relative '../../support/swagger_shared_components'

# rubocop:disable RSpec/VariableName, RSpec/ScatteredSetup, RSpec/RepeatedExample, RSpec/RepeatedDescription, Layout/LineLength
describe 'Higher-Level Reviews', swagger_doc: 'modules/appeals_api/app/swagger/appeals_api/v2/swagger.json', type: :request do
  let(:apikey) { 'apikey' }

  path '/higher_level_reviews' do
    post 'Creates a new Higher-Level Review' do
      tags 'Higher-Level Reviews'
      operationId 'createHlr'
      security [
        { apikey: [] }
      ]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :hlr_body, in: :body, schema: { '$ref' => '#/components/schemas/hlrCreate' }

      parameter in: :body, examples: {
        'minimum fields used' => {
          value: JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'fixtures', 'valid_200996_minimum_v2.json')))
        },
        'all fields used' => {
          value: JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'fixtures', 'valid_200996_v2.json')))
        }
      }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_ssn_header]
      let(:'X-VA-SSN') { '000000000' }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_first_name_header]
      let(:'X-VA-First-Name') { 'first' }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_middle_initial_header]

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_last_name_header]
      let(:'X-VA-Last-Name') { 'last' }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_birth_date_header]
      let(:'X-VA-Birth-Date') { '1900-01-01' }

      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_file_number_header]
      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_insurance_policy_number_header]
      parameter AppealsApi::SwaggerSharedComponents.header_params[:consumer_username_header]
      parameter AppealsApi::SwaggerSharedComponents.header_params[:consumer_id_header]

      response '200', 'Info about a single Higher-Level Review' do
        let(:hlr_body) do
          JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'fixtures', 'valid_200996_minimum_v2.json')))
        end

        schema AppealsApi::SwaggerSharedComponents.response_schemas[:hlr_response_schema]

        before do |example|
          submit_request(example.metadata)
        end

        after do |example|
          response_title = example.metadata[:description]
          example.metadata[:response][:content] = {
            'application/json' => {
              examples: {
                "#{response_title}": {
                  value: JSON.parse(response.body, symbolize_names: true)
                }
              }
            }
          }
        end

        it 'minimum fields used' do |example|
          assert_response_matches_metadata(example.metadata)
        end
      end

      response '200', 'Info about a single Higher-Level Review' do
        let(:hlr_body) do
          JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'fixtures', 'valid_200996_v2.json')))
        end

        schema AppealsApi::SwaggerSharedComponents.response_schemas[:hlr_response_schema]

        before do |example|
          submit_request(example.metadata)
        end

        after do |example|
          response_title = example.metadata[:description]
          example.metadata[:response][:content] = {
            'application/json' => {
              examples: {
                "#{response_title}": {
                  value: JSON.parse(response.body, symbolize_names: true)
                }
              }
            }
          }
        end

        it 'all fields used' do |example|
          assert_response_matches_metadata(example.metadata)
        end
      end

      response '422', 'Violates JSON schema' do
        schema JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'errors',
                                                                 'default.json')))
        let(:hlr_body) do
          request_body = JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'fixtures', 'valid_200996_v2.json')))
          request_body['data']['attributes'].delete('informalConference')
          request_body
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

        it 'returns a 422 response' do |example|
          assert_response_matches_metadata(example.metadata)
        end
      end
    end
  end

  path '/higher_level_reviews/{uuid}' do
    get 'Shows a specific Higher-Level Review. (a.k.a. the Show endpoint)' do
      tags 'Higher-Level Reviews'
      operationId 'showHlr'
      security [
        { apikey: [] }
      ]
      produces 'application/json'

      parameter name: :uuid, in: :path, type: :string, description: 'Higher-Level Review UUID'

      response '200', 'Info about a single Higher-Level Review' do
        schema AppealsApi::SwaggerSharedComponents.response_schemas[:hlr_response_schema]

        hlr = FactoryBot.create(:higher_level_review)
        let(:uuid) { hlr.id }

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

        it 'returns a 200 response' do |example|
          assert_response_matches_metadata(example.metadata)
        end
      end

      response '404', 'Higher-Level Review not found' do
        schema JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'errors', '404.json')))

        let(:uuid) { 'invalid' }

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

        it 'returns a 404 response' do |example|
          assert_response_matches_metadata(example.metadata)
        end
      end
    end
  end

  path '/higher_level_reviews/contestable_issues/{benefit_type}' do
    get 'Returns all contestable issues for a specific veteran.' do
      tags 'Higher-Level Reviews'
      operationId 'hlrContestableIssues'
      description = 'Returns all issues associated with a Veteran that have not previously been decided by a ' \
      'Higher-Level Review as of the receiptDate and bound by benefitType. Not all issues returned are guaranteed '\
      'to be eligible for appeal. Associate these results when creating a new Higher-Level Review.'
      description description
      security [
        { apikey: [] }
      ]
      produces 'application/json'

      parameter name: :benefit_type, in: :path, type: :string,
                description: 'benefit type - Available values: compensation'

      ssn_override = { required: false, description: 'Either X-VA-SSN or X-VA-File-Number is required' }
      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_ssn_header].merge(ssn_override)
      file_num_override = { description: 'Either X-VA-SSN or X-VA-File-Number is required' }
      parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_file_number_header].merge(file_num_override)
      parameter AppealsApi::SwaggerSharedComponents.header_params[:va_receipt_date]

      response '200', 'JSON:API response returning all contestable issues for a specific veteran.' do
        schema '$ref' => '#/components/schemas/contestableIssues'

        let(:benefit_type) { 'compensation' }
        let(:'X-VA-SSN') { '872958715' }
        let(:'X-VA-Receipt-Date') { '2019-12-01' }

        before do |example|
          VCR.use_cassette('caseflow/higher_level_reviews/contestable_issues') do
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

      response '404', 'Veteran not found' do
        schema JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'errors', '404.json')))

        let(:benefit_type) { 'compensation' }
        let(:'X-VA-SSN') { '000000000' }
        let(:'X-VA-Receipt-Date') { '2019-12-01' }

        before do |example|
          VCR.use_cassette('caseflow/higher_level_reviews/not_found') do
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

      response '422', 'Bad receipt date' do
        schema JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'errors',
                                                                 'default.json')))

        let(:benefit_type) { 'compensation' }
        let(:'X-VA-SSN') { '872958715' }
        let(:'X-VA-Receipt-Date') { '1900-01-01' }

        before do |example|
          VCR.use_cassette('caseflow/higher_level_reviews/bad_date') do
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

      response '502', 'Unknown error' do
        # schema JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'errors', 'default.json')))
        # #/errors/0/source is a string 'Appeals Caseflow' instead of an object...

        let(:benefit_type) { 'compensation' }
        let(:'X-VA-SSN') { '872958715' }
        let(:'X-VA-Receipt-Date') { '2019-12-01' }

        before do |example|
          VCR.use_cassette('caseflow/higher_level_reviews/server_error') do
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

        it 'returns a 502 response' do |example|
          assert_response_matches_metadata(example.metadata)
        end
      end
    end
  end

  path '/higher_level_reviews/schema' do
    get 'Gets the Higher-Level Review JSON Schema.' do
      tags 'Higher-Level Reviews'
      operationId 'hlrSchema'
      description 'Returns the JSON Schema for the POST /higher_level_reviews endpoint.'
      security [
        { apikey: [] }
      ]
      produces 'application/json'

      response '200', 'the JSON Schema for POST /higher_level_reviews' do
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

        it 'returns a 200 response' do |example|
          assert_response_matches_metadata(example.metadata)
        end
      end
    end
  end
end
# rubocop:enable RSpec/VariableName, RSpec/ScatteredSetup, RSpec/RepeatedExample, RSpec/RepeatedDescription, Layout/LineLength
